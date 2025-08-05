#!/usr/bin/env bash

function config_mkosi_pre::el_nvidia_from_nvidia() {
	log info "Adding NVIDIA stuff for EL_RELEASE ${EL_RELEASE} "
	# Nothing really done in pre, as adding the repo here creates exclusions that prevent the modules from being installed.
	# Instead, everything is done in the postinst_chroot script. Sorry, cache hit ratio.
}

function mkosi_script_postinst_chroot::nvidia_repo_and_module_stream_and_matching_driver() {
	log info "Determining nvidia module driver version number..."
	# Get the version from the version of any package matching "nvidia" and "-el-lts-modules" in the name.
	declare -r nvidia_version=$(dnf list installed | grep -E 'nvidia.*-el-lts-modules' | awk '{print $2}' | sed 's/-.*//' | cut -d "." -f 4 | xargs echo -n)
	if [[ -z "${nvidia_version}" ]]; then
		log error "No NVIDIA driver version found in installed packages."
		return 1
	fi
	log info "NVIDIA driver version found: '${nvidia_version}'"

	log info "Adding NVIDIA repo EL release ${EL_RELEASE} for TOOLCHAIN_ARCH: ${TOOLCHAIN_ARCH}"
	curl "https://developer.download.nvidia.com/compute/cuda/repos/rhel${EL_RELEASE}/${TOOLCHAIN_ARCH}/cuda-rhel${EL_RELEASE}.repo" > "/etc/yum.repos.d/nvidia-cuda-${EL_RELEASE}.repo"

	log info "Resetting and enabling NVIDIA driver module stream..."
	dnf module reset nvidia-driver -y

	log info "Enabling NVIDIA driver module stream for version ${nvidia_version}..."
	dnf module enable "nvidia-driver:${nvidia_version}" -y

	log info "Installing NVIDIA driver and CUDA packages..."
	dnf install -y nvidia-driver-cuda
}

function mkosi_script_finalize_chroot::nvidia_check_smi_installed() {
	# Cant' run it, as even for --version it requires the driver to be loaded.
	log info "Checking nvidia-smi is installed..."
	command -v nvidia-smi > /dev/null 2>&1 || {
		log error "nvidia-smi command not found. NVIDIA driver installation may have failed."
		return 1
	}
	log info "nvidia-smi command found."
	return 0
}
