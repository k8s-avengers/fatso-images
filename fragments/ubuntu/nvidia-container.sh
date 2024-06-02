#!/usr/bin/env bash

# Add the repo config to the skeketon tree, and mark the pkgs to be installed; this way we capitalize on mkosi's caches
function config_mkosi_pre::nvidia_ctk() {
	log info "Adding nvidia_ctk binaries version"

	# See https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html
	# From https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list
	# $(ARCH) is replaced by apt itself
	# This is done in preparation for deploying the NVIDIA GPU Operator **in no-driver, no toolkit mode**
	# |-> See https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html#pre-installed-nvidia-gpu-drivers-and-nvidia-container-toolkit

	mkosi_stdin_to_work_file "package-manager-tree/etc/apt/sources.list.d" "nvidia-container-toolkit.list" <<- SOURCES_LIST_NVIDIA_CTK
		deb [signed-by=/etc/apt/keyrings/container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/\$(ARCH) /
	SOURCES_LIST_NVIDIA_CTK

	mkosi_config_add_rootfs_packages "nvidia-container-toolkit"
}

# This runs _outside_ of mkosi, but inside the docker container, directly in the WORK_DIR; just add files there
function mkosi_script_pre_mkosi_host::nvidia_ctk_apt_keyring() {
	log info "Adding nvidia_ctk apt-key"
	mkdir -p "package-manager-tree/etc/apt/keyrings"
	curl -fsSL -k https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o "package-manager-tree/etc/apt/keyrings/container-toolkit-keyring.gpg"
}

# This requires containerd to be preinstalled and configured at /etc/containerd/config.toml; use 600 order, since k8s-worker-containerd is 400
function mkosi_script_postinst_chroot::600_nvidia_ctk_install() {
	# Show the installed nvidia-ctk version
	log info "Installed nvidia-container-toolkit version: $(dpkg-query -W -f='${Version}' nvidia-container-toolkit)"
	nvidia-ctk --version

	# Keep a copy of the original config
	cp -v /etc/containerd/config.toml /etc/containerd/config.toml.orig.pre-nvidia-nct

	# Configure containerd for the nvidia runtime
	log info "Configuring containerd for nvidia AS DEFAULT..."
	nvidia-ctk runtime configure --runtime=containerd --set-as-default
	#nvidia-ctk runtime configure --runtime=containerd # non-default version, requires "runtimeClassName: nvidia" on every pod that touches GPU, incompatible with GPU Operator (from Helm)

	# # Show the differences between the new config and the copy
	# log info "Differences in containerd's config.toml after nvidia-ctk configuration..."
	# diff -u /etc/containerd/config.toml.orig.pre-nvidia-nct /etc/containerd/config.toml > toml.diff || true
	# batcat --paging=never --force-colorization --wrap auto --terminal-width 80 --theme=Dracula --language=diff --file-name "containerd config.toml diff after nvidia-ctk" toml.diff
	# cat toml.diff
	# rm -f toml.diff

	# Hold the nvidia_ctk packages
	log info "Holding nvidia-container-toolkit..."
	apt-mark hold nvidia-container-toolkit
}
