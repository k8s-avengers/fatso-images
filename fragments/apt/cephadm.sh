#!/usr/bin/env bash

function config_mkosi_pre::cephadm_determine_ceph_apt_repos_available() {
	MKOSI_CONTENT_ENVIRONMENT["CEPH_RELEASE"]="18.2.2" # Set the CEPH major.minor.point release in env
	MKOSI_CONTENT_ENVIRONMENT["ROOK_RELEASE"]="1.15"   # Set the Rook release in env

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
	declare cephadm_script_url="https://download.ceph.com/rpm-${CEPH_RELEASE}/el9/noarch/cephadm" # ignore the "el9" in here; cephadm is a Python3 zip app

	# Use wget to download the cephadm script
	wget --output-document=/usr/local/sbin/cephadm "${cephadm_script_url}"
	chmod +x /usr/local/sbin/cephadm

	# Deploy Rook scripts for exporting/importing Rook Ceph external clusters. Store them in /opt/rook
	mkdir -p /opt/rook

	# Export script.
	declare rook_export_script_url="https://raw.githubusercontent.com/rook/rook/release-${ROOK_RELEASE}/deploy/examples/create-external-cluster-resources.py"
	wget --output-document=/opt/rook/create-external-cluster-resources.py "${rook_export_script_url}"
	chmod +x /opt/rook/create-external-cluster-resources.py

	# Import script; this really is meant to be run on a k8s node, but let's include it here for completeness.
	declare rook_import_script_url="https://raw.githubusercontent.com/rook/rook/release-${ROOK_RELEASE}/deploy/examples/import-external-cluster.sh"
	wget --output-document=/opt/rook/import-external-cluster.sh "${rook_import_script_url}"
	chmod +x /opt/rook/import-external-cluster.sh

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
	declare -a ceph_docker_images_with_version=(# For 18.2.2 up to 18.2.4; only the ceph image changes in this range
		"quay.io/ceph/ceph:v${CEPH_RELEASE}"
		"quay.io/ceph/keepalived:2.2.4"
		"grafana/loki:2.4.0"
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

	# Helper for bootstrapping a ceph cluster; first a header with env vars, then the script itself
	cat <<- CEPHADM_BOOTSTRAP_HEADER > /usr/local/sbin/script-ceph-bootstrap
		#!/usr/bin/env bash
		declare -g -r CEPH_RELEASE="${CEPH_RELEASE}"
		declare -g -r ROOK_RELEASE="${ROOK_RELEASE}"
	CEPHADM_BOOTSTRAP_HEADER

	# Helper for bootstrapping a ceph cluster; the actual script.
	cat <<- 'CEPHADM_BOOTSTRAP' > /usr/local/sbin/script-ceph-bootstrap
		echo "Bootstrapping a Ceph cluster... please wait." >&2

		declare user="${1:-root}"
		echo "Using user '${user}' for deployment. Confirm with ENTER: " >&2
		read

		# Grab some networking info
		declare net_interface net_ipv4_gateway net_ipv4_addr
		net_interface="$(ip -4 route get 8.8.8.8 | grep via | cut -d " " -f 5 | xargs echo -n)"
		echo "Determined net_interface: ${net_interface}" >&2
		net_ipv4_gateway="$(ip -4 route get 8.8.8.8 | grep via | cut -d " " -f 3 | xargs echo -n)"
		net_ipv4_addr="$(ip -4 addr s dev "${net_interface}" | grep "scope global .* ${net_interface}" | tr -s " " | cut -d " " -f 3 | xargs echo -n | cut -d "/" -f 1)"
		echo "Determined net_ipv4_gateway: ${net_ipv4_gateway}" >&2
		echo "Determined net_ipv4_addr: ${net_ipv4_addr} - confirm with ENTER: ..." >&2
		read

		# options for cephadm (generic)
		declare -a cephadm_opts=("--image" "quay.io/ceph/ceph:v${CEPH_RELEASE}")

		# options for cephadm bootstrap
		declare -a bootstrap_opts=()
		bootstrap_opts+=("--initial-dashboard-user" "admin")
		bootstrap_opts+=("--initial-dashboard-password" "admin")
		bootstrap_opts+=("--mon-ip" "${net_ipv4_addr}")
		bootstrap_opts+=("--dashboard-password-noupdate")
		bootstrap_opts+=("--with-centralized-logging")
		bootstrap_opts+=("--allow-fqdn-hostname")
		bootstrap_opts+=("--ssh-user" "${user}") # use a different ssh user instead of root for deployment

		# examples: 
		# bootstrap_opts+=("--skip-pull") # don't pull images; enable when you're sure the prepulling works
		# bootstrap_opts+=("--orphan-initial-daemons") # to do all manually; otherwise ceph orch/cephadm will autodeploy and manage basic services (mons, mgrs; not osds)
		cephadm  "${cephadm_opts[@]}" bootstrap "${bootstrap_opts[@]}"
	CEPHADM_BOOTSTRAP
	chmod +x -v /usr/local/sbin/script-ceph-bootstrap

	cat <<- 'CEPHADM_DEPLOY_HOSTS' > /usr/local/sbin/script-ceph-deploy-hosts
		#!/usr/bin/env bash
		declare user="${1}"
		shift # remove the first argument

		echo "Deploying Ceph hosts using 'user ${user}': ($*)... please wait." >&2
		# Stop if no arguments are given
		if [[ "$#" -eq 0 ]]; then
			echo "No hosts given to deploy. Exiting." >&2
			exit 1
		fi

		# For each host passed as argument... deploy the Ceph SSH key.
		for host in "$@"; do
			echo "Deploying Ceph ssh key to ${user}@${host}... please wait." >&2
			ssh-copy-id -f -i /etc/ceph/ceph.pub -o StrictHostKeyChecking=no "${user}@${host}"
		done

		# For each host passed as argument... add the host to the Ceph cluster.
		for host in "$@"; do
			echo "Adding ${host} to the Ceph cluster... please wait." >&2
			ceph orch host add "${host}"
		done 

		echo "Done." >&2
	CEPHADM_DEPLOY_HOSTS
	chmod +x -v /usr/local/sbin/script-ceph-deploy-hosts

	cat <<- 'CEPHADM_DEPLOY_OSDS' > /usr/local/sbin/script-ceph-deploy-osds
		#!/usr/bin/env bash
		echo "Deploying Ceph OSDs... please wait." >&2

		ceph orch host ls
		ceph orch device ls

		echo "Confirm the above hosts and devices are correct. Press ENTER to continue, or CTRL+C to cancel." >&2
		read
		ceph orch apply osd --all-available-devices

		# Or, do it manually, one machine and disk per time
		# ceph orch daemon add osd rockpro64:data_devices=/dev/nvme0n1
	CEPHADM_DEPLOY_OSDS
	chmod +x -v /usr/local/sbin/script-ceph-deploy-osds

	# Create an rbb pool called "k8s-rbd-ssd", erasure coded, 2+1. @TODO: this won't work with rook-ceph in external mode, something else is needed. Use replicated for now.
	cat <<- 'CEPHADM_CREATE_RBD_POOL_EC' > /usr/local/sbin/script-ceph-create-rbd-pool-erasure-coded
		#!/usr/bin/env bash
		echo "Creating a Ceph RBD pool... please wait." >&2
		ceph osd erasure-code-profile set ec-2-1 k=2 m=1
		ceph osd pool create k8s-rbd-ssd 64 64 erasure ec-2-1
		ceph osd pool set k8s-rbd-ssd allow_ec_overwrites true
		ceph osd pool application enable k8s-rbd-ssd rbd
	CEPHADM_CREATE_RBD_POOL_EC

	# Create an rbb pool called "k8s-rbd-ssd-repl", replicated, 3x
	cat <<- 'CEPHADM_CREATE_RBD_POOL_EC' > /usr/local/sbin/script-ceph-create-rbd-pool-replicated
		#!/usr/bin/env bash
		echo "Creating a Ceph RBD pool... please wait." >&2
		ceph osd pool create k8s-rbd-ssd-repl 128 128 replicated 
		ceph osd pool set k8s-rbd-ssd-repl size 3 
		ceph osd pool application enable k8s-rbd-ssd-repl rbd
	CEPHADM_CREATE_RBD_POOL_EC

	# Script to call "ceph fs volume create k8s-cephfs-ssd" to create a CephFS volume
	cat <<- 'CEPHADM_CREATE_CEPHFS' > /usr/local/sbin/script-ceph-create-cephfs
		#!/usr/bin/env bash
		echo "Creating a CephFS volume... please wait." >&2
		ceph fs volume create k8s-cephfs-ssd
	CEPHADM_CREATE_CEPHFS

	# Export to Rook Ceph external cluster
	cat <<- 'CEPHADM_EXPORT_ROOK' > /usr/local/sbin/script-ceph-export-rook-k8s
		#!/usr/bin/env bash

		declare consumercluster="${1:-consumercluster}"
		echo "Consumer cluster name: '${consumercluster}'; confirm with ENTER." >&2
		read

		echo "Exporting to Rook Ceph external cluster... please wait." >&2

		declare -a args=()
		args+=("--namespace" "rook-ceph")
		args+=("--format" "bash")
		args+=("--rbd-data-pool-name" "k8s-rbd-ssd-repl")
		args+=("--cephfs-filesystem-name" "k8s-cephfs-ssd")
		args+=("--k8s-cluster-name" "${consumercluster}") # give the name of the k8s cluster; useful when sharing Ceph across multiple clusters

		python3 /opt/rook/create-external-cluster-resources.py "${args[@]}"
	CEPHADM_EXPORT_ROOK

	# Make all scripts executable
	chmod -v +x /usr/local/sbin/script-ceph-*

}
