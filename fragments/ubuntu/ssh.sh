#!/usr/bin/env bash

function config_mkosi_pre::ssh() {
	declare -a pkgs=(
		"openssh-server"
		"ssh-import-id"        # for importing SSH keys from Launchpad
		"python3-launchpadlib" # workaround missing dependency for ssh-import-id
	)
	mkosi_config_add_rootfs_packages "${pkgs[@]}"
}

# Making this dynamic is left as an exercise to the reader; hint: you can create new functions inside a function
function mkosi_script_postinst_chroot::ssh_keys() {
	# add ssh keys
	ssh-import-id gh:rpardini
	ssh-import-id gh:ArdaXi
	#ssh-import-id gh:willemm
	ssh-import-id gh:yifongau
}
