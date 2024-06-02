#!/usr/bin/env bash

# Add the repo config to the skeketon tree, and mark the pkgs to be installed; this way we capitalize on mkosi's caches
function config_mkosi_pre::nvidia_nct() {
	log warn "Adding nvidia_nct binaries version"

	# See https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
	# From https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list
	# $(ARCH) is replaced by apt itself

	mkosi_stdin_to_work_file "package-manager-tree/etc/apt/sources.list.d" "nvidia-container-toolkit.list" <<- SOURCES_LIST_NCT
		deb [signed-by=/etc/apt/keyrings/container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/\$(ARCH) /
	SOURCES_LIST_NCT

	mkosi_config_add_rootfs_packages "nvidia-container-toolkit"
}

# This runs _outside_ of mkosi, but inside the docker container, directly in the WORK_DIR; just add files there
function mkosi_script_pre_mkosi_host::nvidia_nct_apt_keyring() {
	log warn "Adding nvidia_nct apt-key"
	mkdir -p "package-manager-tree/etc/apt/keyrings"
	curl -fsSL -k https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o "package-manager-tree/etc/apt/keyrings/container-toolkit-keyring.gpg"
}

# This requires containerd to be preinstalled and configured at /etc/containerd/config.toml; use 600 order, since k8s-worker-containerd is 400
function mkosi_script_postinst_chroot::600_nvidia_nct_install() {
	# Keep a copy of the original config
	cp -v /etc/containerd/config.toml /etc/containerd/config.toml.orig.pre-nvidia-nct

	# @TODO: might wanna make it the default runtime, to avoid runtimeClass requirements?
	log info "Configuring containerd for nvidia_nct..."
	nvidia-ctk runtime configure --runtime=containerd

	# Hold the nvidia_nct packages
	apt-mark hold nvidia-container-toolkit
}
