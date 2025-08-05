#!/usr/bin/env bash

function config_mkosi_pre::el_9_base_pkgs() {
	# Pass down EL_RELEASE to the mkosi environment (postinst, etc)
	MKOSI_CONTENT_ENVIRONMENT["EL_RELEASE"]="${EL_RELEASE}"

	declare -a pkgs=(
		vim-minimal
		nano
		less
		tree
		curl
		wget
		bash
		bash-completion
		xfsprogs
		btrfs-progs # EPEL
		sysstat
		sudo
		bc
		hdparm
		psmisc
		jq
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
		zstd
	)
	mkosi_config_add_rootfs_packages "${pkgs[@]}"
}
