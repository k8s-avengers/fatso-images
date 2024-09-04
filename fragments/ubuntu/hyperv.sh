#!/usr/bin/env bash

function config_mkosi_pre::ubuntu_hyperv() {
	mkosi_config_add_rootfs_packages "linux-cloud-tools-generic" # this causes systemd failures if enabled on a non-Hyper-V VM
}
