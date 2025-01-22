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

function mkosi_script_postinst_chroot::docker_workarounds_nofile_and_use_containerd_image_store() {
	log info "Configuring Docker to use the containerd image store; /var/lib/containerd will store the images et al..."
	mkdir -p /etc/docker
	echo '{ "features" : { "containerd-snapshotter": true } }' > /etc/docker/daemon.json

	log info "Applying workarounds for LimitNOFILE problems in docker and containerd from Docker, Inc..."
	mkdir -p /etc/systemd/system/docker.service.d
	cat <<- EOD > /etc/systemd/system/docker.service.d/override.conf
		# See https://github.com/moby/moby/issues/38814 and https://github.com/containerd/containerd/pull/8924
		[Service]
		LimitNOFILE=1024:524288
	EOD
	mkdir -p /etc/systemd/system/containerd.service.d
	cat <<- EOD > /etc/systemd/system/containerd.service.d/override.conf
		# See https://github.com/moby/moby/issues/38814 and https://github.com/containerd/containerd/pull/8924
		[Service]
		LimitNOFILE=1024:524288
	EOD
	log info "Workarounds & containerd-image-store done for Docker, Inc..."
}

function mkosi_script_finalize_chroot::docker_full_enable() {
	log info "Enabling docker service..."
	systemctl enable docker
}
