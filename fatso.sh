#!/usr/bin/env bash

set -e

source lib/common.sh
source lib/fragments.sh
source lib/mkosi_helpers.sh
source lib/script_builder.sh

# Get the full directory path of this script
declare -g SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log info "SCRIPT_DIR=${SCRIPT_DIR}"

install_dependencies
fragment_function_names_sanity_check
check_docker_daemon_for_sanity

declare -g -r FLAVOR="${1}"
declare -g -r FLAVOR_DIR="flavors/${FLAVOR}"
declare -g -r FLAVOR_CONF="${FLAVOR_DIR}/flavor.conf.sh"

# Check FLAVOR is set and FLAVOR_DIR exists and also the config file
[[ -z "${FLAVOR}" ]] && log error "FLAVOR is not set; please pass it as 1st argument." && exit 1
[[ ! -d "${FLAVOR_DIR}" ]] && log error "FLAVOR_DIR '${FLAVOR_DIR}' does not exist" && exit 1
[[ ! -f "${FLAVOR_CONF}" ]] && log error "FLAVOR_CONF '${FLAVOR_CONF}' does not exist" && exit 1

# the rest of the arguments are extra fragments to include, handled below
shift

# Source the FLAVOR_CONF
# shellcheck disable=SC1090 # yeah you know dynamic sourcing
source "${FLAVOR_CONF}"

# Check BUILDER is set
[[ -z "${BUILDER}" ]] && log error "BUILDER is not set" && exit 1
log info "FLAVOR=${FLAVOR} uses BUILDER=${BUILDER}"

declare -g -r BUILDER_DIR="builders/${BUILDER}"
declare -g -r BUILDER_CONF="${BUILDER_DIR}/builder.conf.sh"
log info "BUILDER_DIR=${BUILDER_DIR}"
log info "BUILDER_CONF=${BUILDER_CONF}"

# Check BUILDER_DIR exists
[[ ! -d "${BUILDER_DIR}" ]] && log error "BUILDER_DIR '${BUILDER_DIR}' does not exist" && exit 1
# Check BUILDER_CONF exists
[[ ! -f "${BUILDER_CONF}" ]] && log error "BUILDER_CONF '${BUILDER_CONF}' does not exist" && exit 1

# Source the BUILDER_CONF
# shellcheck disable=SC1090
source "${BUILDER_CONF}"

# Check that BUILDER_DESCRIPTION is set, or bail
[[ -z "${BUILDER_DESCRIPTION}" ]] && log error "BUILDER_DESCRIPTION is not set" && exit 1
log info "BUILDER_DESCRIPTION=${BUILDER_DESCRIPTION}"

# Same for BUILDER_CACHE_PKGS_ID
[[ -z "${BUILDER_CACHE_PKGS_ID}" ]] && log error "BUILDER_CACHE_PKGS_ID is not set" && exit 1
log info "BUILDER_CACHE_PKGS_ID=${BUILDER_CACHE_PKGS_ID}"

# Add extra cmdline arguments to FLAVOR_FRAGMENTS
FLAVOR_FRAGMENTS+=("${@}")
# Make it read-only from now
declare -g -a -r FLAVOR_FRAGMENTS
####################################################################################################################################################################################

# Customization for the builder image. @TODO convert to interface/impl
# If found in the root of the project, it will be used by copying it in place.
declare -g -r BUILDER_EARLY_INIT_SCRIPT="${BUILDER_DIR}/early-init.docker.sh"
if [[ -f "${SCRIPT_DIR}/early-init.docker.${BUILDER}.sh" ]]; then
	log info "Customizing builder image with early-init.docker.${BUILDER}.sh"
	cp -v "${SCRIPT_DIR}/early-init.docker.${BUILDER}.sh" "${BUILDER_EARLY_INIT_SCRIPT}"
elif [[ -f "${SCRIPT_DIR}/early-init.docker.sh" ]]; then
	log info "Customizing builder image with early-init.docker.sh"
	cp -v "${SCRIPT_DIR}/early-init.docker.sh" "${BUILDER_EARLY_INIT_SCRIPT}"
else
	log info "No custom early-init.docker.sh found, using a no-op default."
	cat <<- DEFAULT_NO_OP > "${BUILDER_EARLY_INIT_SCRIPT}"
		#!/usr/bin/env bash
		echo "No-op early-init.docker.sh, create one in the root of the project to customize the builder image." >&2
		exit 0
	DEFAULT_NO_OP
fi

# Let's hash the builder's Dockerfile plus a few variables
declare -g BUILDER_HASH=""
BUILDER_HASH="$(cat "${BUILDER_DIR}/Dockerfile" "${BUILDER_CONF}" "${BUILDER_EARLY_INIT_SCRIPT}" | sha256sum - | cut -d ' ' -f 1)"
declare -g -r BUILDER_HASH="${BUILDER_HASH:0:8}" # shorten it to 8 characters, make readonly
log info "BUILDER_HASH=${BUILDER_HASH}"

declare -g -r BUILDER_IMAGE_REF="fatso-builder-${BUILDER}:${BUILDER_HASH}"

# Check if Docker local store has this image name BUILDER_IMAGE_REF, if not, build it.
# If the image is in the local docker cache, skip building
if [[ -n "$(docker images -q "${BUILDER_IMAGE_REF}")" ]]; then
	log info "Builder image '${BUILDER_IMAGE_REF}' already present, skip building."
else
	log warn "Builder image ${BUILDER_IMAGE_REF} not found, building..."
	(
		cd "${BUILDER_DIR}" || { log error "crazy about ${BUILDER_DIR}" && exit 1; }
		docker buildx build --progress=plain --load -t "${BUILDER_IMAGE_REF}" .
	)
	log info "Build done for ${BUILDER_IMAGE_REF}"
fi

####################################################################################################################################################################################

# Prepare cache dirs
declare -g -r CACHE_DIR_PKGS="cache/pkgs/${BUILDER_CACHE_PKGS_ID}"
declare -g -r CACHE_DIR_INCREMENTAL="cache/incremental/${FLAVOR}"
declare -g -r CACHE_DIR_WORKSPACE="cache/workspace/${FLAVOR}"
declare -g -r CACHE_DIR_EXTRA="cache/extra/${FLAVOR}"
mkdir -p "${CACHE_DIR_PKGS}" "${CACHE_DIR_INCREMENTAL}" "${CACHE_DIR_WORKSPACE}" "${CACHE_DIR_EXTRA}"
log debug "CACHE_DIR_PKGS=${CACHE_DIR_PKGS}"
log debug "CACHE_DIR_INCREMENTAL=${CACHE_DIR_INCREMENTAL}"
log debug "CACHE_DIR_WORKSPACE=${CACHE_DIR_WORKSPACE}"
log debug "CACHE_DIR_EXTRA=${CACHE_DIR_EXTRA}"

# Lets preprocess the flavor
declare -g -r WORK_DIR="work/flavors/${FLAVOR}"
log info "Using WORK_DIR=${WORK_DIR}"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

# Enable the fragments declared by the flavor
# @TODO allow command-line/env prepending and appending to this
log info "Enabling fragments for flavor '${FLAVOR}'..."
enable_fragments "${FLAVOR_FRAGMENTS[@]}" # this adds extra fragments from the command line
log info "Done enabling fragments for flavor '${FLAVOR}'..."

# make sure mkosi.conf exists, so crudini can do its work on it
touch "${WORK_DIR}/mkosi.conf"

run_fragment_implementations "config_mkosi_init"
declare -g -a MKOSI_ROOTFS_PACKAGES=()
declare -g -A MKOSI_ROOTFS_PACKAGES_ADDED_BY=()
run_fragment_implementations "config_mkosi_pre"

run_fragment_implementations "config_mkosi_post"

log info "Done with configuration part"

log info "Start scripting part with bash magic"

# See https://github.com/systemd/mkosi/blob/main/mkosi/resources/mkosi.md#execution-flow
# and https://github.com/systemd/mkosi/blob/main/mkosi/resources/mkosi.md#scripts
# build_mkosi_script_from_fragments configure "mkosi.configure" # this doesn't work the same as others, expects stdout-json
build_mkosi_script_from_fragments sync "mkosi.sync"
build_mkosi_script_from_fragments prepare "mkosi.prepare" # runs twice, with 'final' and 'build' arguments; the latter is an overlay
build_mkosi_script_from_fragments build "mkosi.build"
build_mkosi_script_from_fragments postinst "mkosi.postinst"
build_mkosi_script_from_fragments finalize "mkosi.finalize"

# those are not really for mkosi, but before/after helpers that will run inside the Docker container
# can be used to twist the image in ways mkosi can't, like pre-downloading things, or post-processing (eg convert to qcow2/vhdx/etc)
# They will be explicitly called before & after mkosi invocation, below
always="yes" include_chroot="no" build_mkosi_script_from_fragments pre_mkosi "pre_mkosi.sh"
always="yes" include_chroot="no" build_mkosi_script_from_fragments post_mkosi "post_mkosi.sh"

log info "Done scripting part with bash magic"

log info "Showing resulting WORK_DIR tree:"
tree -h "${WORK_DIR}"

if [[ "${STOP_BEFORE_BUILDING}" == "yes" ]]; then
	log warn "STOP_BEFORE_BUILDING=yes, stopping."
	batcat --language=ini "${WORK_DIR}/mkosi.conf"
	log warn "STOP_BEFORE_BUILDING=yes, stopping."
	exit 0
fi

# declare -g INCREMENTAL_CACHE_HASH=""
# # Let's hash the final content (cat) of mkosi.conf, so we can use it as cache key for mkosi's incremental cache
# INCREMENTAL_CACHE_HASH="$(cat "${WORK_DIR}/mkosi.conf" | sha256sum - | cut -d ' ' -f 1)"
# log info "INCREMENTAL_CACHE_HASH=${INCREMENTAL_CACHE_HASH}"

####################################################################################################################################################################################
# Version calc, for GHA's benefit

declare -g -r IMAGE_VERSION="${IMAGE_VERSION:-"666"}"

declare CURRENT_DATE_VERSION # yyyymmddhhmm (UTC) - year month day hour minute
CURRENT_DATE_VERSION=$(date -u "+%Y%m%d%H%M")
declare FULL_VERSION="${CURRENT_DATE_VERSION}-${IMAGE_VERSION}"

# Set GH output with the full version, if it's a file
if [[ -n "${GITHUB_OUTPUT}" ]]; then
	log info "Setting FULL_VERSION=${FULL_VERSION} in GITHUB_OUTPUT=${GITHUB_OUTPUT}"
	echo "FULL_VERSION=${FULL_VERSION}" >> "${GITHUB_OUTPUT}"
else
	log debug "GITHUB_OUTPUT is not set, not setting FULL_VERSION=${FULL_VERSION}"
fi

# Prepare output dir (mkosi's output dir)
declare -g -r OUTPUT_DIR="out/flavors/${FLAVOR}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

declare -g -r OUTPUT_IMAGE_FILE_RAW="${OUTPUT_DIR}/image.raw"
log info "Expecting output image at ${OUTPUT_IMAGE_FILE_RAW}"

# Prepare dist dist (final output dir)
declare -g -r DIST_DIR="dist"
mkdir -p "${DIST_DIR}"
declare -g -r DIST_FILE_IMG_RAW_GZ="${DIST_DIR}/${FLAVOR}-v${IMAGE_VERSION}.img.gz"
log info "Distribution file will be at ${DIST_FILE_IMG_RAW_GZ}"

####################################################################################################################################################################################
# Actually build

# Prepare arrays with arguments for mkosi and docker invocation
declare -a mkosi_opts=()
if [[ "${DEBUG_MKOSI}" == "yes" ]]; then
	mkosi_opts+=("--debug")
fi
mkosi_opts+=("--output-dir=/out")                   # mapped below
mkosi_opts+=("--cache-dir=/cache/incremental")      # mapped below
mkosi_opts+=("--incremental")                       # mapped below
mkosi_opts+=("--package-cache-dir=/cache/packages") # mapped below
mkosi_opts+=("--workspace-dir=/cache/workspace")    # mapped below
# Attention: /cache/extra is available, but not mapped to mkosi; use it for pre/post scripts only

# if http_proxy is set, pass it to mkosi via --proxy-url
if [[ -n "${http_proxy}" ]]; then
	log info "http_proxy is set, passing it to mkosi via --proxy-url (${http_proxy})"
	mkosi_opts+=("--proxy-url=${http_proxy}")
else
	log debug "http_proxy is not set, skipping --proxy-url"
fi

declare -a docker_opts=()
docker_opts+=("run" "--rm")
[[ -t 0 ]] && docker_opts+=("-it") # If terminal is interactive, add -it
docker_opts+=("--privileged")      # Couldn't make it work without this.
docker_opts+=("-v" "${SCRIPT_DIR}/${WORK_DIR}:/work")
docker_opts+=("-v" "${SCRIPT_DIR}/${OUTPUT_DIR}:/out")
docker_opts+=("-v" "${SCRIPT_DIR}/${CACHE_DIR_PKGS}:/cache/packages")
docker_opts+=("-v" "${SCRIPT_DIR}/${CACHE_DIR_INCREMENTAL}:/cache/incremental")
docker_opts+=("-v" "${SCRIPT_DIR}/${CACHE_DIR_WORKSPACE}:/cache/workspace")
docker_opts+=("-v" "${SCRIPT_DIR}/${CACHE_DIR_EXTRA}:/cache/extra")
docker_opts+=("${BUILDER_IMAGE_REF}")

# Important: command _after_ the options
declare real_cmd="/usr/local/bin/mkosi ${mkosi_opts[*]} build"
log info "Real mkosi invocation: ${real_cmd}"

docker_opts+=("/bin/bash" "-c" "/usr/local/bin/mkosi --version && bash pre_mkosi.sh && chown ${UID} -R . && ${real_cmd} && bash post_mkosi.sh && chown ${UID} -R .") # possible escaping hell here

# @TODO: allow further customization of the mkosi command line

# Run the docker command, and thus, mkosi
log info "Running mkosi under Docker..."
log debug "Running docker with: ${docker_opts[*]}"
docker "${docker_opts[@]}"

log info "Done building using mkosi! ${FLAVOR}"

####################################################################################################################################################################################
# Compress the image from OUTPUT_IMAGE_FILE_RAW to DIST_FILE_IMG_RAW_GZ, using pigz
declare size_orig_human size_compress_human
# get a human representation of the size, use "du -h"
size_orig_human=$(du --si "${OUTPUT_IMAGE_FILE_RAW}" | cut -f 1)
log info "Compressing image to ${DIST_FILE_IMG_RAW_GZ}"
pigz -1 -c "${OUTPUT_IMAGE_FILE_RAW}" > "${DIST_FILE_IMG_RAW_GZ}"
size_compress_human=$(du --si "${DIST_FILE_IMG_RAW_GZ}" | cut -f 1)
log info "Done compressing image to ${DIST_FILE_IMG_RAW_GZ} from ${size_orig_human} to ${size_compress_human}."

log info "Distribution done."
