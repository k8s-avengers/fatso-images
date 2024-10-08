#!/usr/bin/env bash

function config_mkosi_post::110_debian_base_distro() { # Override the stuff in the Ubuntu base
	# Basic stuff for Debian bookworm/stable
	mkosi_conf_begin_edit "base"
	mkosi_conf_config_value "Distribution" "Distribution" "debian"
	mkosi_conf_config_value "Distribution" "Release" "bookworm"
	mkosi_conf_config_value "Distribution" "Repositories" "main,contrib,non-free,non-free-firmware"
	#mkosi_conf_config_value "Distribution" "Mirror" "http://deb.debian.org/debian"
	mkosi_conf_finish_edit "base"
}

function config_mkosi_pre::010_debian_base() {
	mkosi_config_add_rootfs_packages "linux-image-amd64" # Debian-specific; main image and modules
}
