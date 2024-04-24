#!/usr/bin/env bash

# Config file for flavor

declare -g -r BUILDER="fedora"
declare -g -r BUILDER_CACHE_PKGS_ID="rocky-9"

declare -g -r EL_DISTRO="rocky"
declare -g -r EL_RELEASE="9"
declare -g -r EL_REPOSITORIES="epel"

declare -g -a FLAVOR_FRAGMENTS=(
	"common_base"
	"common_bootable"
	"el/dnf"
)

# "Inline" fragment functions!
function config_mkosi_pre::el_9_pkgs() {
	declare -a pkgs=(
		nano
		less
		curl
		wget
		bash
		bash-completion
		xfsprogs
		sysstat
		kernel
		kernel-modules-extra
		microcode_ctl
		linux-firmware
		htop
		screen
		tmux
		zsh
		hwdata
		rsyslog
		pciutils
		usbutils
		sg3_utils
		lvm2
		#hyperv-daemons
		#hyperv-tools
		which
	)
	mkosi_config_add_rootfs_packages "${pkgs[@]}"
}
