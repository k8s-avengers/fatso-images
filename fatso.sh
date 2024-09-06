#!/usr/bin/env bash

set -e
#set -o nounset ## set -u : exit the script if you try to use an uninitialised variable
set -o errtrace # trace ERR through - enabled
set -o errexit  ## set -e : exit the script if any statement returns a non-true return value - enabled

source lib/common.sh
source lib/fragments.sh
source lib/inventory.sh
source lib/mkosi_helpers.sh
source lib/script_builder.sh

# Get the full directory path of this script
declare -g SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log info "SCRIPT_DIR=${SCRIPT_DIR}"

install_dependencies
fragment_function_names_sanity_check
check_docker_daemon_for_sanity

declare -g -r FLAVOR_DIR="${SCRIPT_DIR}/flavors"

# @TODO process all inventories...; is order relevant?
for one_inventory in flavors/inventory_*.sh; do
	log info "Processing inventory '${one_inventory}'..."
	# shellcheck disable=SC1090 # dynamic sourcing, don't fret.
	source "${one_inventory}"
done

declare -g -a all_final_flavors=()
declare -g -A flavor_invocations=()
process_inventories

log warn "all_final_flavors=${all_final_flavors[*]}"

declare -g -r FLAVOR="${1}"
# If empty, bail.
[[ -z "${FLAVOR}" ]] && log error "FLAVOR is not set; please pass it as 1st argument." && exit 1
log info "Looking for flavor '${FLAVOR}'..."
declare -g -r FLAVOR_INVOCATION="${flavor_invocations[${FLAVOR}]}"
# if the flavor is not found, bail
[[ -z "${FLAVOR_INVOCATION}" ]] && log error "Flavor '${FLAVOR}' not found in inventory" && exit 1

log info "Found flavor invocation: ${FLAVOR_INVOCATION}"

declare -g BASE_FLAVOR TARGET_FLAVOR VENDOR_FLAVOR # vars to be set by the invocation
#### eval the invocation; this sets the variables BASE_FLAVOR, TARGET_FLAVOR, VENDOR_FLAVOR
eval "${FLAVOR_INVOCATION}"
declare -g -r BASE_FLAVOR TARGET_FLAVOR VENDOR_FLAVOR # make those read-only from now
log info "FLAVOR=${FLAVOR} BASE_FLAVOR=${BASE_FLAVOR} TARGET_FLAVOR=${TARGET_FLAVOR} VENDOR_FLAVOR=${VENDOR_FLAVOR}"

# Prepare the variables that are to be set by the flavor functions.
declare -g BUILDER BUILDER_CACHE_PKGS_ID FLAVOR_DISTRO
declare -g -a FLAVOR_FRAGMENTS=()

# Now run the flavor functions, beginning with the base, then the target, then the vendor.
"flavor_base_${BASE_FLAVOR}"
"flavor_target_${TARGET_FLAVOR}"
"flavor_vendor_${VENDOR_FLAVOR}"

log info "Done running flavor functions."
log info "FLAVOR=${FLAVOR} BASE_FLAVOR=${BASE_FLAVOR} TARGET_FLAVOR=${TARGET_FLAVOR} VENDOR_FLAVOR=${VENDOR_FLAVOR}"
log info "BUILDER=${BUILDER} BUILDER_CACHE_PKGS_ID=${BUILDER_CACHE_PKGS_ID} FLAVOR_DISTRO=${FLAVOR_DISTRO}"
log info "FLAVOR_FRAGMENTS=${FLAVOR_FRAGMENTS[*]}"

# Check they're all set, otherwise bail.
[[ -z "${BUILDER}" ]] && log error "BUILDER is not set by flavor '${FLAVOR}'" && exit 1
[[ -z "${BUILDER_CACHE_PKGS_ID}" ]] && log error "BUILDER_CACHE_PKGS_ID is not set by flavor '${FLAVOR}'" && exit 1
[[ -z "${FLAVOR_DISTRO}" ]] && log error "FLAVOR_DISTRO is not set by flavor '${FLAVOR}'" && exit 1
[[ ${#FLAVOR_FRAGMENTS[@]} -eq 0 ]] && log error "FLAVOR_FRAGMENTS is empty by flavor '${FLAVOR}'" && exit 1

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

# the rest of the arguments are extra fragments to include
shift
# Add extra cmdline arguments to FLAVOR_FRAGMENTS
FLAVOR_FRAGMENTS+=("${@}")
# Make it read-only from now
declare -g -a -r FLAVOR_FRAGMENTS

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

####################################################################################################################################################################################

# Prepare output dir (mkosi's output dir)
declare -g -r OUTPUT_DIR="out/flavors/${FLAVOR}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Prepare dist dist (final output dir, for eg compressed, versioned, converted after mkosi is done; see output_xxx fragments and common_base)
declare -g -r DIST_DIR="dist"
mkdir -p "${DIST_DIR}"

####################################################################################################################################################################################

# Prepare WORK_DIR; this is gonna be /work in the Docker container
declare -g -r WORK_DIR="work/flavors/${FLAVOR}"
log info "Using WORK_DIR=${WORK_DIR}"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

##### Generate configuration and scripts for mkosi
# Enable the fragments declared by the flavor + command line
log info "Enabling fragments for flavor '${FLAVOR}'..."
enable_fragments "${FLAVOR_FRAGMENTS[@]}" # enables _all_ fragments
log info "Done enabling fragments for flavor '${FLAVOR}'..."

# make sure mkosi.conf exists, so crudini can do its work on it
touch "${WORK_DIR}/mkosi.conf"

# Some shared-state variables, to control which fragments will be included into the builder scripts.
# This is done so changes to an unrelated fragment don't compromise the builder's Docker cache hit ratio.
# Fragments can add themselves to those arrays using their config functions.
declare -g -a BUILDER_FRAGMENTS_EARLY=() BUILDER_FRAGMENTS_LATE=()

# Initialize variables; very basic initial configuration
# These can define their own shared-state (...global) variables
run_fragment_implementations "config_mkosi_init"

# Main configuration part; change variables;
run_fragment_implementations "config_mkosi_pre"

# Final configuration; render variables to scripts/configuration; make them read-only
run_fragment_implementations "config_mkosi_post"

log info "Done with configuration part"

####################################################################################################################################################################################

log info "Start script generation..."

# See https://github.com/systemd/mkosi/blob/main/mkosi/resources/mkosi.md#execution-flow
# and https://github.com/systemd/mkosi/blob/main/mkosi/resources/mkosi.md#scripts
# build_mkosi_script_from_fragments configure "mkosi.configure" # this doesn't work the same as others, expects stdout-json
build_mkosi_script_from_fragments sync "mkosi.sync"
build_mkosi_script_from_fragments prepare "mkosi.prepare" # runs twice, with 'final' and 'build' arguments; the latter is an overlay
build_mkosi_script_from_fragments build "mkosi.build"
build_mkosi_script_from_fragments postinst "mkosi.postinst"
build_mkosi_script_from_fragments finalize "mkosi.finalize"

# Customization for the builder image
declare -g -r BUILDER_EARLY_INIT_SCRIPT="${BUILDER_DIR}/builder_dockerfile_early.sh"
declare -g -r BUILDER_LATE_INIT_SCRIPT="${BUILDER_DIR}/builder_dockerfile_late.sh"

# run in the context of the builder Dockerfile
frag_var="BUILDER_FRAGMENTS_EARLY" always="yes" create_mkosi_script_from_fragments_specific "builder_dockerfile_early_host" "${BUILDER_EARLY_INIT_SCRIPT}"
frag_var="BUILDER_FRAGMENTS_LATE" always="yes" create_mkosi_script_from_fragments_specific "builder_dockerfile_late_host" "${BUILDER_LATE_INIT_SCRIPT}"

# those are not really for mkosi, but before/after helpers that will run inside the Docker container
# can be used to twist the image in ways mkosi can't, like pre-downloading things, or post-processing (eg convert to qcow2/vhdx/etc)
# They will be explicitly called before & after mkosi invocation, below
always="yes" create_mkosi_script_from_fragments_specific "pre_mkosi_host" "${WORK_DIR}/pre_mkosi.sh"
always="yes" create_mkosi_script_from_fragments_specific "post_mkosi_host" "${WORK_DIR}/post_mkosi.sh"

log info "Done with script generation."

log info "Showing resulting WORK_DIR tree:"
tree -h "${WORK_DIR}" || true

if [[ "${STOP_BEFORE_BUILDING}" == "yes" ]]; then
	log warn "STOP_BEFORE_BUILDING=yes, stopping."
	batcat --language=ini "${WORK_DIR}/mkosi.conf"
	log warn "STOP_BEFORE_BUILDING=yes, stopping."
	exit 0
fi

####################################################################################################################################################################################
# Actually build; first build the builder Docker image, then use it to run mkosi

log info "Preparing builder..."

declare -g -r BUILDER_IMAGE_REF="fatso-builder-${BUILDER}:local"

log info "Building builder image '${BUILDER_IMAGE_REF}'"
declare -a docker_build_args=()
if [[ ${DOCKER_HAS_BUILDX} -gt 0 ]]; then # global; set by common's check_docker_daemon_for_sanity() to 1 if buildx is detected (via docker info)
	docker_build_args+=("--progress=plain")  # plain logs under buildx
fi

docker_build_args+=("--build-arg" "PROXY_NO_PROXY=${no_proxy:-"${NO_PROXY}"}")          # repass env var as ARG; will be set into ENVs by Dockerfile
docker_build_args+=("--build-arg" "PROXY_HTTP_PROXY=${http_proxy:-"${HTTP_PROXY}"}")    # repass env var as ARG; will be set into ENVs by Dockerfile
docker_build_args+=("--build-arg" "PROXY_HTTPS_PROXY=${https_proxy:-"${HTTPS_PROXY}"}") # repass env var as ARG; will be set into ENVs by Dockerfile
log info "Building builder image with docker build options: ${docker_build_args[*]}"

(
	cd "${BUILDER_DIR}" || { log error "crazy about ${BUILDER_DIR}" && exit 1; }
	docker build "${docker_build_args[@]}" -t "${BUILDER_IMAGE_REF}" .
)
log info "Build done for builder ${BUILDER_IMAGE_REF}"
####################################################################################################################################################################################

####################################################################################################################################################################################
# Actually use the builder to build

# Prepare arrays with arguments for mkosi and docker invocation
declare -a mkosi_opts=()
if [[ "${DEBUG_MKOSI}" == "yes" ]]; then
	mkosi_opts+=("--debug")
fi
mkosi_opts+=("--output-dir=/out")                   # mapped below
mkosi_opts+=("--package-cache-dir=/cache/packages") # mapped below
mkosi_opts+=("--workspace-dir=/cache/workspace")    # mapped below
# Attention: /cache/extra is available, but not mapped to mkosi; use it for pre/post scripts only

# The incremental cache speeds up rebuilds, eg, for development.
# It has the _very_ unfortunate downside of not-checking pkg versions, only names; thus critical security fixes might be missed.
# It is highly recommended to use a fragment to apt upgrade / yum upgrade forcibly to guarantee pkgs are up-to-date.
# Also, depending on the CI pipeline runners setup, if jobs land on random runners, this only causes disk usage and churn.
if [[ "${INCREMENTAL_CACHE:-"no"}" == "yes" ]]; then # thus set INCREMENTAL_CACHE=no to skip it
	mkosi_opts+=("--cache-dir=/cache/incremental")      # mapped below
	mkosi_opts+=("--incremental")                       # mapped below
fi

# if http_proxy is set, pass it to mkosi via --proxy-url
if [[ -n "${http_proxy:-"${HTTP_PROXY}"}" ]]; then
	log info "http_proxy is set, passing it to mkosi via --proxy-url (${http_proxy:-"${HTTP_PROXY}"})"
	mkosi_opts+=("--proxy-url=${http_proxy:-"${HTTP_PROXY}"}")
else
	log debug "http_proxy is not set, skipping --proxy-url"
fi

# if no_proxy is set, pass it to mkosi via --proxy-exclude=
if [[ -n "${no_proxy}" ]]; then
	log info "no_proxy is set, passing it to mkosi via --proxy-exclude (${no_proxy})"
	mkosi_opts+=("--proxy-exclude==${no_proxy}")
else
	log debug "no_proxy is not set, skipping --proxy-exclude="
fi

declare -a docker_opts=()
docker_opts+=("run" "--rm")
[[ -t 0 ]] && docker_opts+=("-it") # If terminal is interactive, add -it
docker_opts+=("--privileged")      # Couldn't make it work without this.

docker_opts+=("--env" "GITHUB_OUTPUT=${GITHUB_OUTPUT}") # Pass-down the GITHUB_OUTPUT variable

docker_opts+=("-v" "${SCRIPT_DIR}/${WORK_DIR}:/work")
docker_opts+=("-v" "${SCRIPT_DIR}/${OUTPUT_DIR}:/out")
docker_opts+=("-v" "${SCRIPT_DIR}/${DIST_DIR}:/dist")
docker_opts+=("-v" "${SCRIPT_DIR}/${CACHE_DIR_PKGS}:/cache/packages")
docker_opts+=("-v" "${SCRIPT_DIR}/${CACHE_DIR_INCREMENTAL}:/cache/incremental")
docker_opts+=("-v" "${SCRIPT_DIR}/${CACHE_DIR_WORKSPACE}:/cache/workspace")
docker_opts+=("-v" "${SCRIPT_DIR}/${CACHE_DIR_EXTRA}:/cache/extra")
docker_opts+=("${BUILDER_IMAGE_REF}")

# Important: command _after_ the options
declare real_cmd="/usr/local/bin/mkosi ${mkosi_opts[*]} build"
log info "Real mkosi invocation: ${real_cmd}"

# @TODO: this is extremely convoluted and shall be remade into a separate on-disk script with trap for user-abort (Ctrl-C)
# @TODO: until then beware 1) escaping hell 2) the fact set -e is _not_ in effect inside the -c and 3) dont press Ctrl-C when running lol
# @TODO: allow further customization of the mkosi command line
docker_opts+=(
	"/bin/bash"
	"-c"
	"if [[ -f /work/mkosi.env.exports.sh ]] then source /work/mkosi.env.exports.sh; fi; declare result=66; /usr/local/bin/mkosi --version && bash pre_mkosi.sh && chown ${UID} -R /work /out /cache /dist && ${real_cmd} && bash post_mkosi.sh && result=0; chown ${UID} -R /work /out /cache /dist; exit \$result"
)

# Run the docker command, and thus, mkosi
log info "Running mkosi under Docker..."
log info "Running docker with: ${docker_opts[*]}"
docker "${docker_opts[@]}"

log info "Done building using mkosi! ${FLAVOR}"

####################################################################################################################################################################################

log info "Distribution done."
