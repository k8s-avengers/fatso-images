#!/usr/bin/env bash

function flavor_base_ubuntu() {
	declare -g -r FLAVOR_DISTRO="ubuntu"
	declare -g -r BUILDER="ubuntu"
	declare -g -r BUILDER_CACHE_PKGS_ID="ubuntu-noble"
	declare -g -a FLAVOR_FRAGMENTS=(
		"common_base" "common_bootable"
		"apt/base" "ubuntu/base"
		"apt/ssh" "apt/grub"
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_ubuntu-cloud() {
	flavor_base_ubuntu # inherit from ubuntu
	# Add cloud fragments
	FLAVOR_FRAGMENTS+=(
		"apt/cloud"
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_ubuntu-cloud-ceph() {
	flavor_base_ubuntu-cloud # inherit from ubuntu-cloud

	# Add docker.io and cephadm
	FLAVOR_FRAGMENTS+=(
		"apt/docker"  # regular docker.io for Ceph
		"apt/cephadm" # Cephadm; will prepull Docker images during image building
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_ubuntu-cloud-harbor() {
	flavor_base_ubuntu-cloud # inherit from ubuntu-cloud

	FLAVOR_FRAGMENTS+=(
		"apt/docker"    # regular docker.io for Harbor
		"ubuntu/harbor" # Harbor itself; will prepull Docker images during image building
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_ubuntu-cloud-k8s() {
	flavor_base_ubuntu-cloud # inherit from ubuntu-cloud
	FLAVOR_FRAGMENTS+=(
		"ubuntu/k8s-worker-containerd"
		"apt/k8s"
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
# cloud k8s, but with nvidia drivers.
function flavor_base_ubuntu-cloud-k8s-nvidia() {
	flavor_base_ubuntu-cloud-k8s # inherit from ubuntu-cloud-k8s
	# this only makes sense for baremetal targets, warn if not
	if [[ "${TARGET_FLAVOR}" != "baremetal" ]]; then
		log warn "Warning: ubuntu-cloud-k8s-nvidia only makes sense for baremetal targets."
	fi
	FLAVOR_FRAGMENTS+=(
		"ubuntu/k3s" # won't hurt; only deploys scripts
		"ubuntu/nvidia"
		"ubuntu/nvidia-container" # requires k8s-worker-containerd and nvidia
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
# "Workstation" is a non-cloud, floating interfaces (NetworkManager) with wifi suppport. For laptops or development VMs.
function flavor_base_ubuntu-workstation() {
	flavor_base_ubuntu # inherit from ubuntu

	# Add workstation fragments
	FLAVOR_FRAGMENTS+=(
		"apt/networkmanager"
		"apt/wifi" # @TODO: For bare metal, it makes sense to have Wifi support for workstations
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_ubuntu-workstation-k8s() {
	flavor_base_ubuntu-workstation
	FLAVOR_FRAGMENTS+=(
		"ubuntu/k8s-worker-containerd"
		"apt/k8s"
		"ubuntu/k3s" # For workstations, also include the k3s fragments. It's just a bunch of scripts.
	)
}
