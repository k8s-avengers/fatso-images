#!/usr/bin/env bash

function config_mkosi_pre::workstation_packages() {
	mkosi_config_add_rootfs_packages "git"
	mkosi_config_add_rootfs_packages "python3-devel" "python3-pip"
	mkosi_config_add_rootfs_packages "bat" "pipx" # EPEL
}
