#!/usr/bin/env bash

function config_mkosi_pre::cephadm_determine_ceph_apt_repos_available() {
	# Only Debian (not Ubuntu) has upstream Ceph apt repos available.
	# Prepare and set environment variable to be used postinst.
	MKOSI_CONTENT_ENVIRONMENT["USE_CEPH_APT_REPOS"]="no"
	if is_element_in_array "debian/base" "${FLAVOR_FRAGMENTS[@]}"; then
		MKOSI_CONTENT_ENVIRONMENT["USE_CEPH_APT_REPOS"]="yes"
	fi
}

# Limit the rootfs size by instructing the (image-runtime-side) systemd-repart
# This should leave enough free space for an OSD partition using the main/OS disk
# This overrides the 10-root.conf setup by base fragments.
function config_mkosi_post::900_limit_runtime_size_of_rootfs() {
	declare rootfs_grow_limit_gb=20
	log info "Limiting the rootfs runtime grow max size to ${rootfs_grow_limit_gb}GB"
	mkosi_stdin_to_work_file "mkosi.extra/usr/lib/repart.d" "10-root.conf" <<- ROOTFS_REPART_GROW_LIMIT_RUNTIME
		[Partition]
		Type=root
		GrowFileSystem=on
		SizeMaxBytes=$((rootfs_grow_limit_gb * 1024 * 1024 * 1024))
	ROOTFS_REPART_GROW_LIMIT_RUNTIME
}

function mkosi_script_postinst_chroot::deploy_cephadm() {
	declare -g CEPH_RELEASE="18.2.4"                                                              # See https://docs.ceph.com/en/latest/releases/
	declare cephadm_script_url="https://download.ceph.com/rpm-${CEPH_RELEASE}/el9/noarch/cephadm" # ignore the "el9" in here; cephadm is a Python3 zip app

	# Use wget to download the cephadm script
	wget --output-document=/usr/local/sbin/cephadm "${cephadm_script_url}"
	chmod +x /usr/local/sbin/cephadm

	# If available, deploy the upstream Ceph apt repos.
	if [[ "${USE_CEPH_APT_REPOS}" == "yes" ]]; then
		log info "Adding Ceph apt repos & deploying cephadm / ceph-common from apt packages."
		/usr/local/sbin/cephadm add-repo --release reef
		/usr/local/sbin/cephadm install             # installs cephadm itself from repos
		/usr/local/sbin/cephadm install ceph-common # installs ceph-common (eg 'ceph' cli) from repos
		rm -fv /usr/local/sbin/cephadm              # get rid of our locally installed on
	else
		log warn "No Ceph apt repos available for this distribution; using only cephadm containers, no apt packages."
	fi

	# @TODO how to obtain those from ceph/cephadm sources? don't wanna be maintaining this stuff
	declare -a ceph_docker_images_with_version=(
		"quay.io/ceph/keepalived:2.2.4"
		"grafana/loki:2.4.0"
		"quay.io/ceph/ceph:v18"
		"quay.io/ceph/ceph-grafana:9.4.7"
		"quay.io/prometheus/prometheus:v2.43.0"
		"quay.io/prometheus/alertmanager:v0.25.0"
		"quay.io/prometheus/node-exporter:v1.5.0"
		"quay.io/ceph/haproxy:2.3"
		"grafana/promtail:2.4.0"
	)
	do_docker_prepulls_for_args "${ceph_docker_images_with_version[@]}"
}

function mkosi_script_postinst_chroot::helper_scripts() {
	if [[ "${USE_CEPH_APT_REPOS}" == "no" ]]; then
		# Helper for running "cephadm shell ceph" -- which is slow, but works.
		cat <<- 'CEPHADM_SHELL' > /usr/local/sbin/ceph
			#!/usr/bin/env bash
			echo "Running 'ceph $*' in cephadm shell... please wait." >&2
			cephadm shell ceph "$@"
		CEPHADM_SHELL
		chmod +x -v /usr/local/sbin/ceph
	fi

	# @TODO hardcoded names and crap below

	# Helper for bootstrapping a ceph cluster
	cat <<- 'CEPHADM_BOOTSTRAP' > /usr/local/sbin/sample-ceph-bootstrap
		#!/usr/bin/env bash
		echo "Bootstrapping a Ceph cluster... please wait." >&2

		declare -a bootstrap_opts=()
		bootstrap_opts+=("--initial-dashboard-user" "admin")
		bootstrap_opts+=("--initial-dashboard-password" "admin")
		bootstrap_opts+=("--dashboard-password-noupdate")

		hostnamectl hostname "vm09" # NOT fqdn
		bootstrap_opts+=("--mon-ip" "192.168.66.79")

		bootstrap_opts+=("--skip-pull") # FOR PREPULLED!
		bootstrap_opts+=("--with-centralized-logging")

		cephadm bootstrap "${bootstrap_opts[@]}"  
	CEPHADM_BOOTSTRAP
	chmod +x -v /usr/local/sbin/sample-ceph-bootstrap

	cat <<- 'CEPHADM_DEPLOY_HOSTS' > /usr/local/sbin/sample-ceph-deploy-hosts
		#!/usr/bin/env bash
		echo "Deploying Ceph hosts... please wait." >&2

		for num in $(seq 1 8); do
			echo "Num: $num"
			ssh-copy-id -f -i /etc/ceph/ceph.pub -o StrictHostKeyChecking=no root@vm0${num}
			ceph orch host add vm0${num}
		done
	CEPHADM_DEPLOY_HOSTS
	chmod +x -v /usr/local/sbin/sample-ceph-deploy-hosts

	cat <<- 'CEPHADM_DEPLOY_OSDS' > /usr/local/sbin/sample-ceph-deploy-osds
		#!/usr/bin/env bash
		echo "Deploying Ceph OSDs... please wait." >&2

		ceph orch host ls
		ceph orch device ls
		ceph orch apply osd --all-available-devices
	CEPHADM_DEPLOY_OSDS
	chmod +x -v /usr/local/sbin/sample-ceph-deploy-osds

}
