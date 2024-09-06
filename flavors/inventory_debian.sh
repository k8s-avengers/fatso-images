#!/usr/bin/env bash

function flavor_base_debian() {
	declare -g -r FLAVOR_DISTRO_TYPE="apt"
	declare -g -r FLAVOR_DISTRO="debian"
	declare -g -r BUILDER="ubuntu"
	declare -g -r BUILDER_CACHE_PKGS_ID="debian-stable"
	declare -g -a FLAVOR_FRAGMENTS=(
		"common_base" "common_bootable"
		"apt/base" "debian/base"
		"apt/ssh" "apt/grub"
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------

function flavor_base_debian-cloud() {
	flavor_base_debian # inherit from debian
	# Add cloud fragments
	FLAVOR_FRAGMENTS+=(
		"apt/cloud"
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------

function flavor_base_debian-cloud-ceph() {
	flavor_base_debian-cloud # inherit from debian-cloud

	# Add docker.io and cephadm
	FLAVOR_FRAGMENTS+=(
		"apt/docker"  # regular docker.io for Ceph
		"apt/cephadm" # Cephadm; will prepull Docker images during image building
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
