#!/usr/bin/env bash

# Add the repo config to the skeketon tree, this way we capitalize on mkosi's caches
function config_mkosi_pre::kubectl_from_official_obs_repos() {
	log info "Adding kubectl from Official OBS repo for EL release ${EL_RELEASE} "

	mkosi_stdin_to_work_file "package-manager-tree/etc/yum.repos.d" "k8s-el-${EL_RELEASE}.repo" <<- DOCKER_YUM_REPO
		[k8s-el-${EL_RELEASE}]
		name=k8s-el-${EL_RELEASE}
		baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
		enabled=1
		gpgcheck=1
		gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
	DOCKER_YUM_REPO

	mkosi_config_add_rootfs_packages kubectl
}

function mkosi_script_finalize_chroot::check_kubectl_version() {
	log info "Checking kubectl version..."
	kubectl version --client
}
