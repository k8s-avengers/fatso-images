#!/usr/bin/env bash

# Add the repo config to the skeketon tree, this way we capitalize on mkosi's caches
function config_mkosi_pre::docker_full_from_docker() {
	log info "Adding Full Docker from  Docker Repo for EL release ${EL_RELEASE} "

	mkosi_stdin_to_work_file "package-manager-tree/etc/yum.repos.d" "docker-el-${EL_RELEASE}.repo" <<- DOCKER_YUM_REPO
		[docker-el-${EL_RELEASE}]
		name=docker-el-${EL_RELEASE}
		baseurl=https://download.docker.com/linux/rhel/\$releasever/\$basearch/stable
		enabled=1
		gpgcheck=1
		gpgkey=https://download.docker.com/linux/rhel/gpg
	DOCKER_YUM_REPO

	cat "${WORK_DIR}/package-manager-tree/etc/yum.repos.d/docker-el-${EL_RELEASE}.repo"

	mkosi_config_add_rootfs_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

function mkosi_script_finalize_chroot::docker_full_enable() {
	log info "Enabling docker service..."
	systemctl enable docker
}
