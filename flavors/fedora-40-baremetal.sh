#!/usr/bin/env bash

# Config file for flavor

declare -g -r BUILDER="fedora"
declare -g -r BUILDER_CACHE_PKGS_ID="fedora-40"

declare -g -r EL_DISTRO="fedora"
declare -g -r EL_RELEASE="40"
declare -g -r EL_REPOSITORIES="#epel"

declare -g -a FLAVOR_FRAGMENTS=(
	"common_base"
	"common_bootable"
	"el/dnf"
)

# "Inline" fragment functions!
function config_mkosi_pre::fedora_40_pkgs() {
	declare -a pkgs=(
		"nano"
		"less"
		"curl"
		"wget"
		"bash"
		"bash-completion"
		"xfsprogs"
		"sysstat"
		"kernel"
		"kernel-modules"
		"htop"
		"screen"
		"tmux"
		"zsh"
		"hwdata"
		"rsyslog"
		"lvm2"
		"which"
		#"hyperv-daemons"
		#"hyperv-tools"
		"kernel-modules-extra"
		"kernel-tools"
		"microcode_ctl"
		"linux-firmware"
		"pciutils"
		"usbutils"
		"sg3_utils"
	)
	mkosi_config_add_rootfs_packages "${pkgs[@]}"
}
