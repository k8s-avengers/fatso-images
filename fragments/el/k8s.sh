#!/usr/bin/env bash

# Add the repo config to the skeketon tree, this way we capitalize on mkosi's caches
function config_mkosi_pre::k8s_from_official_obs_repos() {
	log info "Adding k8s from Official OBS repo for EL release ${EL_RELEASE} "

	mkosi_stdin_to_work_file "package-manager-tree/etc/yum.repos.d" "k8s-el-${EL_RELEASE}.repo" <<- DOCKER_YUM_REPO
		[k8s-el-${EL_RELEASE}]
		name=k8s-el-${EL_RELEASE}
		baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
		enabled=1
		gpgcheck=1
		gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
	DOCKER_YUM_REPO

	cat "${WORK_DIR}/package-manager-tree/etc/yum.repos.d/k8s-el-${EL_RELEASE}.repo"

	mkosi_config_add_rootfs_packages kubelet kubeadm kubectl
}

# @TODO: postinst chroot to configure k8s-related stuff

function mkosi_script_finalize_chroot::k8s_kubelet_enable() {
	log info "Enabling kubelet service..."
	systemctl enable kubelet
}

function mkosi_script_postinst_chroot::selinux_permissive() {
	log info "Setting SELINUX to permissive...."
	# setenforce 0 || true
	sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
	cat /etc/selinux/config
}
