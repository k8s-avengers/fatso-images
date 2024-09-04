#!/usr/bin/env bash

function config_mkosi_pre::networkmanager() {
	mkosi_config_add_rootfs_packages "network-manager" "modemmanager"
}

function mkosi_script_postinst_chroot::networkmanager() {
	# let NetworkManager manage the network
	touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
	ls -la /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
	sed "s/managed=\(.*\)/managed=true/g" -i /etc/NetworkManager/NetworkManager.conf
	systemctl mask systemd-networkd.service
}
