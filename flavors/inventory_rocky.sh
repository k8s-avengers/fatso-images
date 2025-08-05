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
		"el/k8s-sysctls"
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_rocky-cloud-k8s-el-containerd() {
	flavor_base_rocky-cloud
	FLAVOR_FRAGMENTS+=(
		"el/k8s-el-containerd"
		"el/k8s"
		"el/k8s-sysctls"
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_rocky-noncloud-k8s-el-containerd() {
	flavor_base_rocky
	FLAVOR_FRAGMENTS+=(
		"el/k8s-el-containerd"
		"el/k8s"
		"el/k8s-sysctls"
		"el/repos-enabled" # ship the image with all repos enabled (/etc/yum.repos.d)
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
# cloud k8s, but with nvidia drivers.
function flavor_base_rocky-noncloud-k8s-el-containerd-nvidia() {
	declare -g EL_KERNEL_NVIDIA_NONFREE=yes      # Include nvidia-nonfree kernel modules
	declare -g EL_KERNEL_NVIDIA_OPEN=no          # Include nvidia open source kernel modules
	flavor_base_rocky-noncloud-k8s-el-containerd # inherit from ubuntu-cloud-k8s
	# this only makes sense for baremetal targets, warn if not
	if [[ "${TARGET_FLAVOR}" != "baremetal" ]]; then
		log warn "Warning: rocky-noncloud-k8s-el-containerd-nvidia only makes sense for baremetal targets."
	fi
	FLAVOR_FRAGMENTS+=(
		"el/nvidia"
		"el/nvidia-container"
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_rocky-cloud-workstation() {
	flavor_base_rocky-cloud
	FLAVOR_FRAGMENTS+=(
		"el/docker-ce-full" # full docker with buildx and compose
		"el/kubectl"        # from k8s repo, just kubectl (no kubeadm or kubelet)
		"el/powershell"     # powershell via Microsoft's RPM repo
		"el/azure-cli"      # Azure CLI from Microsoft's RPM repo
		"el/workstation"    # git, python, bat, and other workstation tools
		"el/trivy"          # trivy vulnerability scanner, from Aqua Security's RPM repo
		"el/repos-enabled"  # ship the image with all repos enabled (/etc/yum.repos.d)
		"node-exporter"     # node-exporter running as a systemd service
		"git-dev"           # tools for git: git-credential-manager,
		"k8s-dev"           # node-exporter running as a systemd service
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_rocky-cloud-ado-agent() {
	flavor_base_rocky-cloud
	FLAVOR_FRAGMENTS+=(
		"el/docker-ce-full" # full docker with buildx and compose
		"el/powershell"     # powershell via Microsoft's RPM repo
		"el/ado-agent"      # Azure DevOps build agent 4.x
		"el/trivy"          # trivy vulnerability scanner, from Aqua Security's RPM repo
		"node-exporter"     # node-exporter running as a systemd service
	)
}
