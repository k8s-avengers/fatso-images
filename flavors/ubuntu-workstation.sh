#!/usr/bin/env bash

# "Workstation" is a non-cloud, floating interfaces (NetworkManager) with wifi suppport. For laptops or development VMs.

source "${FLAVOR_DIR}/ubuntu.sh"

# Add workstation fragments
FLAVOR_FRAGMENTS+=(
	"apt/networkmanager"
)
