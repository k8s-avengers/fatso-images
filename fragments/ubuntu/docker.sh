#!/usr/bin/env bash

function config_mkosi_pre::docker_packages() {
	log info "Adding docker.io packages; from Ubuntu upstream repos, not Docker's"
	mkosi_config_add_rootfs_packages "docker.io"
}

function mkosi_script_postinst_chroot::010_early_docker_registry_prefixes_init() {
	log info "Initializing docker registry prefixes dictionary..."
	declare -g -A docker_registry_prefixes=()
	# further fragments might fill this in with prefixes, eg quay.io->harbor.proxy.domain/quay.io
}

function mkosi_script_postinst_chroot::450_finish_registry_prefixes_init() {
	declare -g -r -A docker_registry_prefixes
	log info "Finishing docker registry prefixes dictionary... entries: ${#docker_registry_prefixes[@]}"
}

function mkosi_script_postinst_chroot::050_config_docked_to_use_containerd_image_store() {
	log info "Configuring dockerd to use containerd's image store"
	cat <<- DOCKERD_CONFIG > /etc/docker/daemon.json
		{ "features": {"containerd-snapshotter": true}} 
	DOCKERD_CONFIG
}

# Helper.
function do_docker_prepulls_for_args() {
	log info "Prepulling ${#} images..."
	do_with_dockerd_running_for_prepulls do_docker_prepulls_for_args_internal "${@}"
}

# Helper for doing prepulls from an argument list. Each argument should be a full OCI reference with registry, image, tag.
function do_docker_prepulls_for_args_internal() {
	for img_with_version in "$@"; do
		declare image_to_pull_with_possible_registry_prefix="unknown"
		declare registry_for_image="docker.io" possible_registry="" everything_after_registry="${img_with_version}"
		# does the image have a slash? if not, it's just docker.io
		if [[ "${img_with_version}" == *"/"* ]]; then
			# split by slashes and grab the first occurence
			possible_registry="$(echo "${img_with_version}" | cut -d'/' -f1)"
			# if the alledged registry has a dot, then use that
			if [[ "${possible_registry}" == *"."* ]]; then
				everything_after_registry="$(echo "${img_with_version}" | cut -d'/' -f2-)"
				registry_for_image="${possible_registry}"
			fi
		fi
		log info "Prepulling ${img_with_version} (from registry '${registry_for_image}' image '${everything_after_registry}') ..."

		# check if the image has a registry prefix
		declare prefixed_registry="${registry_for_image}"
		# check if docker_registry_prefixes contains registry_for_image
		if [[ -n "${docker_registry_prefixes["${registry_for_image}"]}" ]]; then
			prefixed_registry="${docker_registry_prefixes["${registry_for_image}"]}"
		fi

		image_to_pull_with_possible_registry_prefix="${prefixed_registry}/${everything_after_registry}"
		log info "Prepulling ${img_with_version} with registry prefix ${registry_for_image} as ${image_to_pull_with_possible_registry_prefix} ..."
		docker pull "${image_to_pull_with_possible_registry_prefix}"

		# If prefixed, retag the image to the original name
		if [[ "${image_to_pull_with_possible_registry_prefix}" != "${img_with_version}" ]]; then
			log info "Retagging ${image_to_pull_with_possible_registry_prefix} to ${img_with_version}..."
			docker tag "${image_to_pull_with_possible_registry_prefix}" "${img_with_version}"
		else
			log info "No need to retag ${image_to_pull_with_possible_registry_prefix} to ${img_with_version}..."
		fi
		log info "Done prepulling ${image_to_pull_with_possible_registry_prefix}..."
	done
}

# Helper function
function do_with_dockerd_running_for_prepulls() {
	log info "Preparing cgroups/containerd/docked for doing prepulls with '$*'"

	declare -i containerd_pid dockerd_pid dockerd_result_code
	declare containerd_logs="/var/log/chroot_containerd.log"
	declare dockerd_logs="/var/log/chroot_dockerd.log"

	# cgroups are not really used (since we're only prepulling images), but dockerd checks for them.
	log info "cgroupfs-mount..."
	mkdir -p /sys/fs/cgroup
	mount -t cgroup2 none /sys/fs/cgroup

	# Since we're in a chroot, start the Docker daemon manually and leave it running in the background.
	# Actually, we need containerd to be up as well.
	containerd > "${containerd_logs}" 2>&1 &
	containerd_pid=$!
	log info "Started containerd with PID ${containerd_pid}"

	# Wait until /run/containerd/containerd.sock exists.
	sleep 1
	while [ ! -e /run/containerd/containerd.sock ]; do
		log info "Waiting for /run/containerd/containerd.sock to exist..."
		batcat "${containerd_logs}" || true
		sleep 1
	done
	log info "Found /run/containerd/containerd.sock. Starting dockerd..."

	dockerd --containerd=/run/containerd/containerd.sock -H unix:///var/run/docker.sock > "${dockerd_logs}" 2>&1 &
	dockerd_result_code=$? dockerd_pid=$!
	log info "Started dockerd with PID ${dockerd_pid} and result code ${dockerd_result_code}"

	# Wait until `docker info` works
	sleep 1
	while ! docker info &> /dev/null; do
		log info "Waiting for dockerd to be ready..."

		log info "Containerd logs:"
		batcat "${containerd_logs}" || true
		log info "Dockerd logs:"
		batcat "${dockerd_logs}" || true
		sleep 1
	done

	log info "dockerd is ready; showing 'docker info'..."
	docker info # docker info -f '{{ .DriverStatus }}'

	log info "dockerd is ready! Executing '${1}'"

	"$@" # Execute the passed command; this is where the actual work is done

	log info "Executed '${1}' -- cleaning up and stopping docked/containerd/cgroups mount..."

	# Stop the Docker daemon.
	kill $dockerd_pid
	sync
	log info "Stopped dockerd with PID ${dockerd_pid}"

	# Stop containerd.
	kill $containerd_pid
	sync
	log info "Stopped containerd with PID ${containerd_pid}"

	# Unmount cgroupfs
	umount /sys/fs/cgroup
	sync

	# Cleanup the logs
	rm -f "${containerd_logs}" "${dockerd_logs}"

	return 0
}
