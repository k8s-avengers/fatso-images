#!/usr/bin/env bash

function config_mkosi_pre::el_9_base_pkgs() {
	declare -a pkgs=(
		nano
		less
		tree
		curl
		wget
		bash
		bash-completion
		xfsprogs
		sysstat
		btop   #  EPEL
		htop   #  EPEL
		screen #  EPEL
		tmux
		zsh
		hwdata
		rsyslog
		pciutils
		usbutils
		sg3_utils
		lvm2
		which
		efibootmgr
		dnf
		yum
		iproute
		iputils
		bind-utils
		openssh-clients
		openssh-server
		hostname
	)
	mkosi_config_add_rootfs_packages "${pkgs[@]}"

	mkosi_conf_begin_edit "mirror"
	mkosi_conf_config_value "Distribution" "Mirror" "http://mirror.nl.stackscale.com" # NO /rocky at the end
	mkosi_conf_finish_edit "mirror"
}
