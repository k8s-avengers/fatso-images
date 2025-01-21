#!/usr/bin/env bash

function config_mkosi_pre::workstation_packages() {
	mkosi_config_add_rootfs_packages "git"
}
