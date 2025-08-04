#!/usr/bin/env bash

function config_mkosi_pre::el_kernel_lts_pkgs() {
	log info "Finding latest version of el-kernel-lts for TOOLCHAIN_ARCH=${TOOLCHAIN_ARCH}..."

	declare EL_KERNEL_LTS_MAJOR_MINOR="${EL_KERNEL_LTS_MAJOR_MINOR:-"6.12"}"
	declare EL_KERNEL_LTS_POINT_RELEASE="${EL_KERNEL_LTS_POINT_RELEASE:-"y"}"
	declare EL_KERNEL_LTS_FLAVOR="${EL_KERNEL_LTS_FLAVOR:-"generic"}"
	declare -r major_minor_nodot="${EL_KERNEL_LTS_MAJOR_MINOR//./}"
	declare EL_KERNEL_DEVEL="${EL_KERNEL_DEVEL:-"no"}"
	declare EL_KERNEL_NVIDIA_NONFREE="${EL_KERNEL_NVIDIA_NONFREE:-"no"}"
	declare EL_KERNEL_NVIDIA_OPEN="${EL_KERNEL_NVIDIA_OPEN:-"no"}"

	declare tag_arch_version_flavor="tags/${TOOLCHAIN_ARCH}-${EL_KERNEL_LTS_MAJOR_MINOR}.y-${EL_KERNEL_LTS_FLAVOR}"
	declare main_kernel_pkgname="kernel_lts_${EL_KERNEL_LTS_FLAVOR}_${major_minor_nodot}${EL_KERNEL_LTS_POINT_RELEASE}"

	log info "Using tag_arch_version_flavor: ${tag_arch_version_flavor} and main_kernel_pkgname: ${main_kernel_pkgname} devel?:${EL_KERNEL_DEVEL}"

	filter_out='grep -v -e "\-headers" -e "\-devel"' \
		find_one_github_release_file_meta "kversions" "kernel" "k8s-avengers/el-kernel-lts" "${tag_arch_version_flavor}" "${main_kernel_pkgname}"

	filter_out='grep -e "\-headers"' \
		find_one_github_release_file_meta "kversions" "headers" "k8s-avengers/el-kernel-lts" "${tag_arch_version_flavor}" "${main_kernel_pkgname}"

	filter_out='grep -e "\-devel"' \
		find_one_github_release_file_meta "kversions" "devel" "k8s-avengers/el-kernel-lts" "${tag_arch_version_flavor}" "${main_kernel_pkgname}"

	find_one_github_release_file_meta "kversions" "nvidiaopen" "k8s-avengers/el-kernel-lts" "${tag_arch_version_flavor}" "nvidia-open"
	find_one_github_release_file_meta "kversions" "nvidianonfree" "k8s-avengers/el-kernel-lts" "${tag_arch_version_flavor}" "nvidia-nonfree"

	find_one_github_release_file_meta "kversions" "px" "k8s-avengers/el-kernel-lts" "${tag_arch_version_flavor}" "px"

	cat "${WORK_DIR}/meta.kversions.conf.sh"

	log info "Adding kernel lts packages to package list..."
	mkosi_config_add_rootfs_packages "${main_kernel_pkgname}"
	mkosi_config_add_rootfs_packages "px"

	if [[ "${EL_KERNEL_DEVEL}" == "yes" ]]; then
		mkosi_config_add_rootfs_packages "${main_kernel_pkgname}-devel"
		mkosi_config_add_rootfs_packages "${main_kernel_pkgname}-headers"
	fi

	# Can't have both nvidia-nonfree and nvidia-open at the same time.
	if [[ "${EL_KERNEL_NVIDIA_NONFREE}" == "yes" && "${EL_KERNEL_NVIDIA_OPEN}" == "yes" ]]; then
		log error "You can't have both nvidia-nonfree and nvidia-open enabled at the same time."
		log error "Please set either EL_KERNEL_NVIDIA_NONFREE or EL_KERNEL_NVIDIA_OPEN to 'no'."
		return 1
	fi

	if [[ "${EL_KERNEL_NVIDIA_NONFREE}" == "yes" ]]; then
		mkosi_config_add_rootfs_packages "nvidia-nonfree"
	fi

	if [[ "${EL_KERNEL_NVIDIA_OPEN}" == "yes" ]]; then
		mkosi_config_add_rootfs_packages "nvidia-open"
	fi

	return 0
}

# This runs outside of mkosi, but inside the Docker container.
function mkosi_script_pre_mkosi_host::el_kernel_lts_download() {
	log info "Downloading el-kernel-lts package..."

	download_one_github_release_file_meta "kversions" "kernel"
	download_one_github_release_file_meta "kversions" "px"

	download_one_github_release_file_meta "kversions" "headers"
	download_one_github_release_file_meta "kversions" "devel"

	download_one_github_release_file_meta "kversions" "nvidiaopen"
	download_one_github_release_file_meta "kversions" "nvidianonfree"
	return 0
}
