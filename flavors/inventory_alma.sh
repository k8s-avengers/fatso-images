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
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_alma-cloud-workstation() {
	flavor_base_alma-cloud
	FLAVOR_FRAGMENTS+=(
		"el/k8s-docker-full" # full docker with buildx and compose
		"el/kubectl"         # from k8s repo, just kubectl (no kubeadm or kubelet)
		"el/powershell"      # powershell via Microsoft's RPM repo
		"el/azure-cli"       # Azure CLI from Microsoft's RPM repo
		"el/workstation"     # git, python, bat, and other workstation tools
		"el/repos-enabled"   # ship the image with all repos enabled (/etc/yum.repos.d)
		"node-exporter"      # node-exporter running as a systemd service
		"git-dev"            # tools for git: git-credential-manager,
		"k8s-dev"            # node-exporter running as a systemd service
	)
}
# ---------------------------------------------------------------------------------------------------------------------------------
function flavor_base_alma-cloud-ado-agent() {
	flavor_base_alma-cloud
	FLAVOR_FRAGMENTS+=(
		"el/k8s-docker-full" # full docker with buildx and compose
		"el/powershell"      # powershell via Microsoft's RPM repo
		"el/ado-agent"       # Azure DevOps build agent 4.x
		"node-exporter"      # node-exporter running as a systemd service
	)
}
