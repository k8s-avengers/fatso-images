#!/usr/bin/env bash

function config_mkosi_pre::el_containerd_pkgs() {
	log info "Finding latest version of el-containerd for EL_RELEASE=${EL_RELEASE} and TOOLCHAIN_ARCH=${TOOLCHAIN_ARCH}..."

	filter_in="grep -e '\.rpm' | grep 'el${EL_RELEASE}' | grep '${TOOLCHAIN_ARCH}' | sed -e 's|%2B|+|'" \
		find_one_github_release_file_meta "containerd" "containerd" "k8s-avengers/el-containerd" "latest" "el-containerd"

	cat "${WORK_DIR}/meta.containerd.conf.sh"

	log info "Adding el-containerd packages to package list..."
	mkosi_config_add_rootfs_packages "el-containerd" # simple name of the package; mkosi builds a temporary repo with the extra-packages in it
}

# This runs outside of mkosi, but inside the Docker container.
function mkosi_script_pre_mkosi_host::el_containerd_download() {
	log info "Downloading el-containerd package..."

	download_one_github_release_file_meta "containerd" "containerd"
}

function mkosi_script_postinst_chroot::400_k8s_el_containerd_check_version() {
	log warn "Printing containerd version..."
	# Check by running it under chroot
	containerd --version

	echo "Config cri-tools to use containerd..."
	cat <<- EOD > /etc/crictl.yaml
		runtime-endpoint: unix:///var/run/containerd/containerd.sock
	EOD
}

function mkosi_script_postinst_chroot::990_late_validate_el-containerd_config_and_pretty_print() {
	# Lets make sure the changes produce valid containerd toml, and use containerd itself to reformat it
	log info "Testing containerd config.toml for validity..."
	mkdir -p /etc/containerd
	containerd config dump > /etc/containerd/config.toml.validated
	log info "containerd config.toml valid."
	mv -v /etc/containerd/config.toml.validated /etc/containerd/config.toml
	cp -v /etc/containerd/config.toml /etc/containerd/config.toml.final.validated.mkosi
	#log info "Final validated containerd config.toml:"
	#cat /etc/containerd/config.toml
}

function mkosi_script_finalize_chroot::el_containerd_enable() {
	log info "Enabling containerd service..."
	systemctl enable containerd.service
}
