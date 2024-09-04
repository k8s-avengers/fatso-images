#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu.sh"

# Add cloud fragments
FLAVOR_FRAGMENTS+=(
	"apt/cloud"
)
