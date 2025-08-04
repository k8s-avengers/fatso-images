function config_mkosi_pre::apt_ssh_import_id() {
	log warn "Enabling ssh-import-id and a hardcoded SSH public key - DO NOT use in production"
	mkosi_config_add_rootfs_packages "ssh-import-id" #"python3-launchpadlib"
}

function mkosi_script_postinst_chroot::apt_ssh_keys() {
	log warn "Enabling ssh-import-id and a hardcoded SSH public key - DO NOT use in production"
	ssh-import-id gh:rpardini
}
