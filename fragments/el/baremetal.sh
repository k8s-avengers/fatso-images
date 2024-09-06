#!/usr/bin/env bash

function config_mkosi_pre::el_9_baremetal_pkgs() {
	mkosi_config_add_rootfs_packages "microcode_ctl" "linux-firmware" "usbutils"
}
