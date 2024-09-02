#!/usr/bin/env bash

function config_mkosi_pre::qemu_guest_agent() {
	log info "Enabling qemu-guest-agent"
	mkosi_config_add_rootfs_packages "qemu-guest-agent"
}
