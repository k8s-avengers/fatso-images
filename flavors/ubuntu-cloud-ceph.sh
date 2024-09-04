#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu-cloud.sh"

FLAVOR_FRAGMENTS+=(
	"apt/docker"  # regular docker.io for Ceph
	"apt/cephadm" # Cephadm; will prepull Docker images during image building
)
