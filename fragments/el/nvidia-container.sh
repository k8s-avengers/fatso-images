#!/usr/bin/env bash

function config_mkosi_pre::nvidia_container_toolkit_do_nothing_in_pre() {
	log info "Adding NVIDIA NCT container-toolkit stuff for EL_RELEASE ${EL_RELEASE} "
	# Nothing really done in pre, as adding the repo here creates exclusions that prevent the modules from being installed.
	# Instead, we will assume the repo was done by nvidia_repo_and_module_stream_and_matching_driver() in the el/nvidia fragment.
}

# This must be run _after_ nvidia_repo_and_module_stream_and_matching_driver in the el/nvidia fragment. Thus 650_
function mkosi_script_postinst_chroot::650_nvidia_container_toolkit_install_package() {
	log info "Installing NVIDIA container toolkit..."
	dnf install -y nvidia-container-toolkit
}

function mkosi_script_postinst_chroot::700_nvidia_ctk_configure_containerd() {
	# Show the installed nvidia-ctk version
	log info "Installed nvidia-container-toolkit version:"
	nvidia-ctk --version

	# If no config.toml exists, create a default one
	if [[ ! -f /etc/containerd/config.toml ]]; then
		log info "No /etc/containerd/config.toml found, creating a default one..."
		mkdir -p /etc/containerd
		containerd config default > /etc/containerd/config.toml
	fi

	# Keep a copy of the original config
	cp -v /etc/containerd/config.toml /etc/containerd/config.toml.orig.pre-nvidia-nct

	# Configure containerd for the nvidia runtime
	log info "Configuring containerd for nvidia, but NOT as default..."
	nvidia-ctk runtime configure --runtime=containerd

	# Keep a good copy in case nvidia-operator decides to frak up later
	cp -v /etc/containerd/config.toml /etc/containerd/config.toml.orig.with.nvidia
}
