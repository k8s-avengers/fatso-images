function config_mkosi_pre::k8s_dev() {
	mkosi_config_add_rootfs_packages "unzip" # thankfully the same across apt and el
}

function mkosi_script_postinst_chroot::k8s_dev_helm_install() {
	log info "k8s-dev: Helm install..." # the script wants /usr/local/bin in the PATH, which it inst for root?
	curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | PATH="/usr/local/bin:${PATH}" bash
	log info "k8s-dev: Helm install done."
}

function mkosi_script_postinst_chroot::k8s_dev_k9s_install() {
	declare version="0.32.7"
	log info "k8s-dev: k9s install version ${version}..."
	declare tarball_fn="k9s_Linux_amd64.tar.gz"
	declare down_url="https://github.com/derailed/k9s/releases/download/v${version}/${tarball_fn}"
	wget --progress=dot:mega -O "/tmp/${tarball_fn}" "${down_url}"
	tar -xvf "/tmp/${tarball_fn}" -C /usr/local/bin
	rm -f "/tmp/${tarball_fn}"
	log info "k8s-dev: k9s install done."
}

function mkosi_script_postinst_chroot::k8s_dev_kubelogin_oidc_install() {
	log info "k8s-dev: kubelogin oidc install..."
	declare version="1.32.0"
	declare zipfile_fn="kubelogin_linux_amd64.zip"
	declare down_url="https://github.com/int128/kubelogin/releases/download/v${version}/${zipfile_fn}"
	wget --progress=dot:mega -O "/tmp/${zipfile_fn}" "${down_url}"
	unzip -o -d /usr/local/bin "/tmp/${zipfile_fn}"
	rm -f "/tmp/${zipfile_fn}"
	log info "k8s-dev: kubelogin oidc install done."
}

function mkosi_script_postinst_chroot::600_k8s_dev_completion() {
	log info "k8s-dev: bash completion..."
	cat <<- 'COMPLETION' > /etc/profile.d/completion_k8s_dev.sh
		source <(kubectl completion bash)
		source <(/usr/local/bin/k9s completion bash)
		source <(/usr/local/bin/helm completion bash)
		source <(/usr/local/bin/kubelogin completion bash)
	COMPLETION
}

function mkosi_script_finalize_chroot::k8s_dev_k9s_version() {
	log info "Checking k9s version..."
	/usr/local/bin/k9s version
}

function mkosi_script_finalize_chroot::k8s_dev_helm_version() {
	log info "Checking Helm version..."
	/usr/local/bin/helm version
}

function mkosi_script_finalize_chroot::k8s_dev_kubelogin_oidc_version() {
	log info "Checking kubelogin oidc version..."
	/usr/local/bin/kubelogin --version
}
