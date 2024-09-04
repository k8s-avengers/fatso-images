#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu-cloud.sh"

FLAVOR_FRAGMENTS+=(
	"apt/docker"    # regular docker.io for Harbor
	"ubuntu/harbor" # Harbor itself; will prepull Docker images during image building
)
