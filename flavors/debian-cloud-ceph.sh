#!/usr/bin/env bash

source "${FLAVOR_DIR}/debian-cloud.sh"

# Add docker.io and cephadm
FLAVOR_FRAGMENTS+=(
	"apt/docker"  # regular docker.io for Ceph
	"apt/cephadm" # Cephadm; will prepull Docker images during image building
)
