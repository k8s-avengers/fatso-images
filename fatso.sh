#!/usr/bin/env bash

set -e

source lib/common.sh

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






