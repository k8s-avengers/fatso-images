#!/usr/bin/env bash

function flavor_base_rocky() {
	declare -g -r FLAVOR_DISTRO_TYPE="el"
	declare -g -r FLAVOR_DISTRO="rocky"
	declare -g -r BUILDER="fedora"
	declare -g -r BUILDER_CACHE_PKGS_ID="rocky-9"

	declare -g -r EL_DISTRO="rocky"
	declare -g -r EL_RELEASE="9"
	declare -g -r EL_REPOSITORIES="" # EPEL is added manually via fragment el/epel_mirror + EL_RELEASE config

	declare -g -a FLAVOR_FRAGMENTS=(
		"common_base"
		"common_bootable"
		"el/epel_mirror"
		"el/dnf" "el/el9_base" "el/el_rocky_base"
		"el/grub"
		"el/networkmanager"
		"el/el9_kernel_lts" # Custom kernel
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_rocky-cloud() {
	flavor_base_rocky
	FLAVOR_FRAGMENTS+=("el/cloud")
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_rocky-cloud-k8s() {
	flavor_base_rocky-cloud
	FLAVOR_FRAGMENTS+=(
		"el/k8s-docker-containerd"
		"el/k8s"
	)
}
