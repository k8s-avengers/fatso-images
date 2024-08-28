#!/usr/bin/env bash

function config_mkosi_pre::containerd_from_os() {
	log info "Adding containerd from OS repo"
	mkosi_config_add_rootfs_packages containerd # @TODO: more?
}

function mkosi_script_finalize_chroot::os_containerd_enable() {
	log info "Enabling containerd service..."
	systemctl enable containerd
}

# @TODO: postinst chroot to configure containerd
