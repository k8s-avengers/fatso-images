#!/usr/bin/env bash

function config_mkosi_pre::docker_packages() {
	log info "Adding docker.io packages; from Ubuntu upstream repos, not Docker's"
	mkosi_config_add_rootfs_packages "docker.io"
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
	while ! docker info; do
		log info "Waiting for dockerd to be ready..."

		log info "Containerd logs:"
		batcat "${containerd_logs}" || true
		log info "Dockerd logs:"
		batcat "${dockerd_logs}" || true
		sleep 1
	done
	log info "dockerd is ready! Executing '$*'"

	"$@" # Execute the passed command; this is where the actual work is done

	log info "Executed '$*' -- cleaning up and stopping docked/containerd/cgroups mount..."

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
