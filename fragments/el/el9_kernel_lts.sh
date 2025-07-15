#!/usr/bin/env bash

function config_mkosi_pre::el_kernel_lts_pkgs() {
	log info "Finding latest version of el-kernel-lts..."

	filter_out='grep -v -e "\-headers" -e "\-devel"' \
		find_one_github_release_file_meta "kversions" "kernel" "k8s-avengers/el-kernel-lts" "tags/el9-6.1.y-generic" "kernel_lts_generic_61y"

	find_one_github_release_file_meta "kversions" "px" "k8s-avengers/el-kernel-lts" "tags/el9-6.1.y-generic" "px"

	cat "${WORK_DIR}/meta.kversions.conf.sh"

	log info "Adding kernel lts packages to package list..."
	mkosi_config_add_rootfs_packages "kernel_lts_generic_61y" # simple name of the package; mkosi builds a temporary repo with the extra-packages in it
	mkosi_config_add_rootfs_packages "px"
}

# This runs outside of mkosi, but inside the Docker container.
function mkosi_script_pre_mkosi_host::el_kernel_lts_download() {
	log info "Downloading el-kernel-lts package..."

	download_one_github_release_file_meta "kversions" "kernel"
	download_one_github_release_file_meta "kversions" "px"
}
