#!/usr/bin/env bash

function config_mkosi_pre::ubuntu_cloud() {
	declare -a pkgs=(
		"cloud-init"        # for cloud-init itself
		"eatmydata"         # cloud-init likes this for faster package installation (fsync -> no-op)
		"systemd-timesyncd" # for time synchronization from DHCP option 42

		"networkd-dispatcher" # for handling networkd events
		"netplan.io"          # for configuring network interfaces (systemd-networkd backend)
	)
	mkosi_config_add_rootfs_packages "${pkgs[@]}"
}

function mkosi_script_postinst_chroot::cloud_fixes() {
	# make cloud-init happy by waiting for network (systemd-neworkd+netplan version)
	systemctl enable systemd-networkd-wait-online.service

	# make everyone who has ntp configured in their dhcp happy, and everyone else unhappy
	systemctl enable systemd-time-wait-sync.service
}
