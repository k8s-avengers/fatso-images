#!/usr/bin/env bash

set -e

source lib/common.sh

# Get the full directory path of this script
declare -g SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log info "SCRIPT_DIR=${SCRIPT_DIR}"

check_docker_daemon_for_sanity

declare -g -r FLAVOR="${1:-"ubuntu-noble-baremetal"}"
declare -g -r FLAVOR_DIR="flavors/${FLAVOR}"
declare -g -r FLAVOR_CONF="${FLAVOR_DIR}/flavor.conf.sh"

# Check FLAVOR is set and FLAVOR_DIR exists and also the config file
[[ -z "${FLAVOR}" ]] && log error "FLAVOR is not set" && exit 1
[[ ! -d "${FLAVOR_DIR}" ]] && log error "FLAVOR_DIR '${FLAVOR_DIR}' does not exist" && exit 1
[[ ! -f "${FLAVOR_CONF}" ]] && log error "FLAVOR_CONF '${FLAVOR_CONF}' does not exist" && exit 1

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

####################################################################################################################################################################################

# Customization for the builder image.
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
declare -g -r CACHE_DIR_INCREMENTAL="cache/incremental/${FLAVOR}" # @TODO needs a hash etc
mkdir -p "${CACHE_DIR_PKGS}" "${CACHE_DIR_INCREMENTAL}"
log info "CACHE_DIR_PKGS=${CACHE_DIR_PKGS}"
log info "CACHE_DIR_INCREMENTAL=${CACHE_DIR_INCREMENTAL}"

# Lets preprocess the flavor
declare -g -r WORK_DIR="work/flavors/${FLAVOR}"
log info "Using WORK_DIR=${WORK_DIR}"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

# For now just copy the sources...
cp -r -v "${FLAVOR_DIR}"/* "${WORK_DIR}"/
# ... and ensure any *.postinst files, if any, are executable
find "${WORK_DIR}" -name "*.postinst" -exec chmod +x {} \;
find "${WORK_DIR}" -name "*.postinst.chroot" -exec chmod +x {} \;

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
mkosi_opts+=("--output-dir=/out")                   # mapped below
mkosi_opts+=("--cache-dir=/cache/incremental")      # mapped below
mkosi_opts+=("--package-cache-dir=/cache/packages") # mapped below

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
docker_opts+=("${BUILDER_IMAGE_REF}")
docker_opts+=("/bin/bash" "-c" "/usr/local/bin/mkosi --version && ls -laR && /usr/local/bin/mkosi ${mkosi_opts[*]}") # possible escaping hell here

# @TODO: allow further customization of the mkosi command line

# Run the docker command
log info "Running docker with: ${docker_opts[*]}"
docker "${docker_opts[@]}"

log info "Done building mkosi! ${FLAVOR}"

####################################################################################################################################################################################
# Compress the image from OUTPUT_IMAGE_FILE_RAW to DIST_FILE_IMG_RAW_GZ, using pigz
declare -i size_orig size_compress
size_orig=$(stat -c %s "${OUTPUT_IMAGE_FILE_RAW}")
log info "Compressing image to ${DIST_FILE_IMG_RAW_GZ}"
pigz -1 -c "${OUTPUT_IMAGE_FILE_RAW}" > "${DIST_FILE_IMG_RAW_GZ}"
size_compress=$(stat -c %s "${DIST_FILE_IMG_RAW_GZ}")
log info "Done compressing image to ${DIST_FILE_IMG_RAW_GZ} from ${size_orig} to ${size_compress} bytes."

log info "Distribution done."
