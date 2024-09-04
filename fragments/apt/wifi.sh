#!/usr/bin/env bash

function config_mkosi_pre::wifi() {
	mkosi_config_add_rootfs_packages "rfkill" "wpasupplicant"
	# @TODO: Realtek / Broadcom / etc firmware
}
