#!/usr/bin/env bash

# Ubuntu: relies on apt/base being active

function config_mkosi_pre::010_ubuntu_base() {
	mkosi_config_add_rootfs_packages "linux-image-generic" # Ubuntu-specific; main image and modules (not headers etc)
	mkosi_config_add_rootfs_packages "linux-tools-generic" # Ubuntu-specific; Debian ships separate packages for each kernel userspace tool.
}

function config_mkosi_post::100_ubuntu_base_distro() {
	# Basic stuff for ubuntu noble
	mkosi_conf_begin_edit "base"
	mkosi_conf_config_value "Distribution" "Distribution" "ubuntu"
	mkosi_conf_config_value "Distribution" "Release" "noble"
	mkosi_conf_config_value "Distribution" "Repositories" "main,restricted,universe,multiverse"
	mkosi_conf_config_value "Distribution" "Mirror" "http://archive.ubuntu.com/ubuntu"
	mkosi_conf_finish_edit "base"
}
