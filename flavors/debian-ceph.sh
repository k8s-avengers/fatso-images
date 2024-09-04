#!/usr/bin/env bash

# Config file for flavor

declare -g -r BUILDER="ubuntu"
declare -g -r BUILDER_CACHE_PKGS_ID="debian-stable"

declare -g -a FLAVOR_FRAGMENTS=(
	"common_base"
	"common_bootable"

	"apt/base"
	"debian/base"

	"ubuntu/ssh"
	"ubuntu/grub"
	"ubuntu/cloud"

	"ubuntu/docker"  # regular docker.io for Ceph
	"ubuntu/cephadm" # Cephadm; will prepull Docker images during image building
)
