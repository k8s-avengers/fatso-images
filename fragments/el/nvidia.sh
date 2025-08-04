#!/usr/bin/env bash

# Add the repo config to the skeketon tree, this way we capitalize on mkosi's caches
function config_mkosi_pre::el_nvidia_from_nvidia() {
	log info "Adding NVIDIA stuff from NVIDIA Repo for EL release ${EL_RELEASE} "

	mkosi_stdin_to_work_file "package-manager-tree/etc/yum.repos.d" "nvidia-${EL_RELEASE}.repo" <<- NVIDIA_REPO_CUDA
		$(curl "https://developer.download.nvidia.com/compute/cuda/repos/rhel${EL_RELEASE}/${TOOLCHAIN_ARCH}/cuda-rhel${EL_RELEASE}.repo")
	NVIDIA_REPO_CUDA

	# @TODO: packages should be installed in postinst, cos we need to setup up dnf module streams first to match the kernel driver version
}

function mkosi_script_finalize_chroot::nvidia_show_version() {
	log info "Checking nvidia stuff version..."
}
