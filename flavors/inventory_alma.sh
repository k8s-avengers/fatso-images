#!/usr/bin/env bash

function flavor_base_alma() {
	declare -g -r FLAVOR_DISTRO_TYPE="el"
	declare -g -r FLAVOR_DISTRO="alma"
	declare -g -r BUILDER="fedora"
	declare -g -r BUILDER_CACHE_PKGS_ID="alma-9"

	declare -g -r EL_DISTRO="alma"
	declare -g -r EL_RELEASE="9"
	declare -g -r EL_REPOSITORIES="" # EPEL is added manually via fragment el/epel_mirror + EL_RELEASE config

	declare -g -a FLAVOR_FRAGMENTS=(
		"common_base"
		"common_bootable"
		"el/epel_mirror"
		"el/dnf" "el/el9_base" # custom mirror? -> "el/el_alma_base"
		"el/grub"
		"el/networkmanager"
		"el/el9_kernel_lts" # Custom kernel
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_alma-cloud() {
	flavor_base_alma
	FLAVOR_FRAGMENTS+=("el/cloud")
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_alma-cloud-k8s() {
	flavor_base_alma-cloud
	FLAVOR_FRAGMENTS+=(
		"el/k8s-docker-containerd"
		"el/k8s"
	)
}
