#!/usr/bin/env bash

source "${FLAVOR_DIR}/debian.sh"

# Add cloud fragments
FLAVOR_FRAGMENTS+=(
	"apt/cloud"
)
