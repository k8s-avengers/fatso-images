function mkosi_script_postinst_chroot::git_dev_git_credential_manager_install() {
	# git-credential-manager
	log info "Installing git-credential-manager version ${version}..."
	declare version="2.6.1"
	declare tarball_fn="gcm-linux_amd64.${version}.tar.gz"
	declare down_url="https://github.com/git-ecosystem/git-credential-manager/releases/download/v${version}/${tarball_fn}"
	wget --no-check-certificate --progress=dot:mega -O "/tmp/${tarball_fn}" "${down_url}"
	tar -xvf "/tmp/${tarball_fn}" -C /usr/local/bin
	rm -f "/tmp/${tarball_fn}"

}

function mkosi_script_finalize_chroot::git_dev_git_credential_manager_check() {
	log info "Check git-credential-manager version..."
	/usr/local/bin/git-credential-manager --version
}
