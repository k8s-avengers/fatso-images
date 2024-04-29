#!/usr/bin/env bash

# Add the repo config to the skeketon tree, this way we capitalize on mkosi's caches
function config_mkosi_pre::containerd_from_docker() {
	log info "Adding containerd from  Docker Repo for EL release ${EL_RELEASE} "

	mkosi_stdin_to_work_file "package-manager-tree/etc/yum.repos.d" "docker-el-${EL_RELEASE}.repo" <<- DOCKER_YUM_REPO
		[docker-el-${EL_RELEASE}]
		name=docker-el-${EL_RELEASE}
		baseurl=https://download.docker.com/linux/centos/\$releasever/\$basearch/stable
		enabled=1
		gpgcheck=1
		gpgkey=https://download.docker.com/linux/centos/gpg
	DOCKER_YUM_REPO

	cat "${WORK_DIR}/package-manager-tree/etc/yum.repos.d/docker-el-${EL_RELEASE}.repo"

	mkosi_config_add_rootfs_packages containerd # @TODO: more?
}

function mkosi_script_finalize_chroot::containerd_enable() {
	log info "Enabling containerd service..."
	systemctl enable containerd
}

# @TODO: postinst chroot to configure containerd
