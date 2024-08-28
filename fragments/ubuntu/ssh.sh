#!/usr/bin/env bash

function config_mkosi_pre::ssh() {
	declare -a pkgs=(
		"openssh-server"
	)
	mkosi_config_add_rootfs_packages "${pkgs[@]}"
}
