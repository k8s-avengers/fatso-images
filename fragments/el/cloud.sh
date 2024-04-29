#!/usr/bin/env bash

function config_mkosi_pre::cloud_package() {
	mkosi_config_add_rootfs_packages "cloud-init" "toilet" # toilet just for demo purposes
}

function mkosi_script_postinst_chroot::cloud_wait_nm() {
	log info "Setting cloud-init to up wait for NM (POSTINST)..."
	systemctl enable NetworkManager-wait-online.service
}

function mkosi_script_finalize_chroot::ccloud_services_enable() {
	log info "Enabling cloud-init services in FINALIZE..."
	systemctl enable cloud-init-local.service
	systemctl enable cloud-init.service
}
