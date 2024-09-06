#!/usr/bin/env bash

function config_mkosi_pre::el_hyperv_pkgs() {
	mkosi_config_add_rootfs_packages "hyperv-daemons" "hyperv-tools"
}
