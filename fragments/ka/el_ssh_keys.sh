function config_mkosi_pre::el_ssh_import_id() {
	log warn "Enabling ssh-import-id via pip and a hardcoded gh key - DO NOT use in production"
	mkosi_config_add_rootfs_packages "python3-pip" "python3-setuptools"
}

function mkosi_script_postinst_chroot::el_ssh_keys() {
	log warn "Enabling ssh-import-id and a hardcoded SSH public key - DO NOT use in production"
	pip3 install ssh-import-id
	/usr/local/bin/ssh-import-id gh:rpardini
}
