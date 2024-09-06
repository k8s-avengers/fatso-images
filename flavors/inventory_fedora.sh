#!/usr/bin/env bash

function flavor_base_fedora() {
	declare -g -r FLAVOR_DISTRO_TYPE="el"
	declare -g -r FLAVOR_DISTRO="fedora"
	declare -g -r BUILDER="fedora"
	declare -g -r BUILDER_CACHE_PKGS_ID="fedora-40"
	declare -g -r EL_DISTRO="fedora"
	declare -g -r EL_RELEASE="40"
	declare -g -r EL_REPOSITORIES="" # Fedora doesn't need EPEL -- EPEL _comes_ from fedora main repo

	declare -g -a FLAVOR_FRAGMENTS=(
		"common_base" "common_bootable"
		"el/dnf" "el/el9_base" "el/el_fedora_base"
		"el/grub"
		"el/networkmanager"
	)

	# "Inline" fragment functions!
	# shellcheck disable=SC2317 # untrue, shellcheck is just confused when functions are defined inside funtions.
	function config_mkosi_pre::fedora_standard_fedora_kernel() {
		log info "Adding Fedora standard kernel package"
		mkosi_config_add_rootfs_packages "kernel"
	}
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_fedora-cloud() {
	flavor_base_fedora
	FLAVOR_FRAGMENTS+=(
		"el/cloud"
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_fedora-cloud-k8s() {
	flavor_base_fedora-cloud
	FLAVOR_FRAGMENTS+=(
		"el/k8s-containerd" # From Fedora's own repo -- NOT Docker's
		"el/k8s"
	)
}
