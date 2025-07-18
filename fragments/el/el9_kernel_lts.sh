#!/usr/bin/env bash

function config_mkosi_pre::el_kernel_lts_pkgs() {
	log info "Finding latest version of el-kernel-lts for TOOLCHAIN_ARCH=${TOOLCHAIN_ARCH}..."

	declare EL_KERNEL_LTS_MAJOR_MINOR="${EL_KERNEL_LTS_MAJOR_MINOR:-"6.12"}"
	declare EL_KERNEL_LTS_POINT_RELEASE="${EL_KERNEL_LTS_POINT_RELEASE:-"y"}"
	declare EL_KERNEL_LTS_FLAVOR="${EL_KERNEL_LTS_FLAVOR:-"generic"}"
	declare -r major_minor_nodot="${EL_KERNEL_LTS_MAJOR_MINOR//./}"

	declare tag_arch_version_flavor="tags/${TOOLCHAIN_ARCH}-${EL_KERNEL_LTS_MAJOR_MINOR}.y-${EL_KERNEL_LTS_FLAVOR}"
	declare main_kernel_pkgname="kernel_lts_${EL_KERNEL_LTS_FLAVOR}_${major_minor_nodot}${EL_KERNEL_LTS_POINT_RELEASE}"

	log info "Using tag_arch_version_flavor: ${tag_arch_version_flavor} and main_kernel_pkgname: ${main_kernel_pkgname}"

	filter_out='grep -v -e "\-headers" -e "\-devel"' \
		find_one_github_release_file_meta "kversions" "kernel" "k8s-avengers/el-kernel-lts" "${tag_arch_version_flavor}" "${main_kernel_pkgname}"

	find_one_github_release_file_meta "kversions" "px" "k8s-avengers/el-kernel-lts" "${tag_arch_version_flavor}" "px"

	cat "${WORK_DIR}/meta.kversions.conf.sh"

	log info "Adding kernel lts packages to package list..."
	mkosi_config_add_rootfs_packages "${main_kernel_pkgname}"
	mkosi_config_add_rootfs_packages "px"
}

# This runs outside of mkosi, but inside the Docker container.
function mkosi_script_pre_mkosi_host::el_kernel_lts_download() {
	log info "Downloading el-kernel-lts package..."

	download_one_github_release_file_meta "kversions" "kernel"
	download_one_github_release_file_meta "kversions" "px"
}
