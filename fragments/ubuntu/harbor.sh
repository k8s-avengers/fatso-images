#!/usr/bin/env bash

function config_mkosi_pre::harbor_pkgs() {
	log info "Harbor requires docker-compose; adding docker-compose-v2 pkg from Ubuntu repos."
	mkosi_config_add_rootfs_packages "docker-compose-v2"
}

function mkosi_script_postinst_chroot::deploy_harbor() {
	declare harbor_version="2.11.1" # without the 'v' in front
	declare harbor_installer_url="https://github.com/goharbor/harbor/releases/download/v${harbor_version}/harbor-online-installer-v${harbor_version}.tgz"

	mkdir -p /opt
	cd /opt || exit 1
	wget --output-document=harbor-online-installer.tgz "${harbor_installer_url}"
	tar xzf harbor-online-installer.tgz
	rm harbor-online-installer.tgz
	log info "Harbor scripts are at /opt/harbor"

	declare -a harbor_docker_images=(
		"goharbor/redis-photon"
		"goharbor/harbor-registryctl"
		"goharbor/registry-photon"
		"goharbor/nginx-photon"
		"goharbor/harbor-log"
		"goharbor/harbor-jobservice"
		"goharbor/harbor-core"
		"goharbor/harbor-portal"
		"goharbor/harbor-db"
		"goharbor/prepare"
	)

	# shellcheck disable=SC2317 # used right below, but shellcheck's not too smart.
	function harbor_prepulls() {
		for img in "${harbor_docker_images[@]}"; do
			declare img_with_version="${img}:v${harbor_version}" # 'v' is part of the tag
			log info "Prepulling ${img_with_version} ..."
			docker pull "${img_with_version}"
			log info "Done prepulling ${img_with_version}..."
		done
	}

	log info "Doing Harbor prepulls..."
	do_with_dockerd_running_for_prepulls harbor_prepulls

}
