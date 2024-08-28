#!/usr/bin/env bash

# Config file for flavor

declare -g -r BUILDER="fedora"
declare -g -r BUILDER_CACHE_PKGS_ID="rocky-9"

declare -g -r EL_DISTRO="rocky"
declare -g -r EL_RELEASE="9"
declare -g -r EL_REPOSITORIES="" # EPEL is added manually via fragment el/epel_mirror + EL_RELEASE config

declare -g -a FLAVOR_FRAGMENTS=(
	"common_base"
	"common_bootable"
	"el/dnf"
	"el/epel_mirror"
	"el/el9_base"
	"el/grub"
	"el/networkmanager"
	"el/el9_kernel_lts"
	"el/k8s-docker-containerd"
	"el/k8s"
	"el/cloud"
)

# "Inline" fragment functions!
function config_mkosi_pre::el_9_baremetal_pkgs() {
	mkosi_config_add_rootfs_packages "microcode_ctl" "linux-firmware" "usbutils"
}
