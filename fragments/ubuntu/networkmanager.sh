#!/usr/bin/env bash

function config_mkosi_pre::networkmanager() {
	mkosi_config_add_rootfs_packages "network-manager" "modemmanager"
}
