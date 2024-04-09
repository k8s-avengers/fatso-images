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

# Let's hash the builder's Dockerfile plus a few variables
declare -g BUILDER_HASH=""
BUILDER_HASH="$(cat "${BUILDER_DIR}/Dockerfile" "${BUILDER_CONF}" | sha256sum - | cut -d ' ' -f 1)"
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

# Prepare output dir
declare -g -r OUTPUT_DIR="out/flavors/${FLAVOR}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Prepare cache dirs
declare -g -r CACHE_DIR_PKGS="cache/pkgs/${BUILDER_CACHE_PKGS_ID}"
mkdir -p "${CACHE_DIR_PKGS}"
log info "CACHE_DIR_PKGS=${CACHE_DIR_PKGS}"

# Lets preprocess the flavor
declare -g -r WORK_DIR="work/flavors/${FLAVOR}"
log info "Using WORK_DIR=${WORK_DIR}"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"

# For now just copy the sources...
cp -r -v "${FLAVOR_DIR}"/* "${WORK_DIR}"/

# Now, let's run the builder image, mapping WORK_DIR and OUTPUT_DIR into the container via mounts
docker run -it --rm --privileged \
	-v "${SCRIPT_DIR}/${WORK_DIR}:/work" \
	-v "${SCRIPT_DIR}/${OUTPUT_DIR}:/out" \
	-v "${SCRIPT_DIR}/${CACHE_DIR_PKGS}:/cache/packages" \
	"${BUILDER_IMAGE_REF}" \
	/bin/bash -c "mkosi -O /out --cache-dir=/cache/packages"
