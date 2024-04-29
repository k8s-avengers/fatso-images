#!/usr/bin/env bash

function config_mkosi_pre::el_networkmanager() {
	mkosi_config_add_rootfs_packages "NetworkManager" "NetworkManager-tui"
}
