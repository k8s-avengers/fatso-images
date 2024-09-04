#!/usr/bin/env bash

function config_mkosi_pre::debian_hyperv() {
	mkosi_config_add_rootfs_packages "hyperv-daemons" # this causes systemd failures if enabled on a non-Hyper-V VM
}
