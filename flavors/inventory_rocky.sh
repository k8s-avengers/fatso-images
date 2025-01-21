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
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_rocky-cloud-workstation() {
	flavor_base_rocky-cloud
	FLAVOR_FRAGMENTS+=(
		"el/k8s-docker-full" # full docker with buildx and compose
		"el/kubectl"         # from k8s repo, just kubectl (no kubeadm or kubelet)
		"el/powershell"      # powershell via Microsoft's RPM repo
		"el/azure-cli"       # Azure CLI from Microsoft's RPM repo
		"el/workstation"     # git and other workstation tools, if any
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_rocky-cloud-ado-agent() {
	flavor_base_rocky-cloud
	FLAVOR_FRAGMENTS+=(
		"el/k8s-docker-full" # full docker with buildx and compose
		"el/powershell"      # powershell via Microsoft's RPM repo
		"el/workstation"     # git and other workstation tools, if any
		"el/ado-agent"       # Azure DevOps build agent 4.x
	)
}
