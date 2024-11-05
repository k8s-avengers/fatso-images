#!/usr/bin/env bash

# This runs outside of mkosi, but inside the Docker container.
function mkosi_script_pre_mkosi_host::el_kernel_lts_download() {
	log info "Downloading el-kernel-lts package..."

	# source the file written by the config
	source kversions.conf.sh

	# curl --include --verbose "${kernel_lts_release_api_url}"

	download_one_kernel_lts_file "${kernel_url}" "${kernel_file}"
	download_one_kernel_lts_file "${px_url}" "${px_file}"
}

function config_mkosi_pre::el_kernel_lts_pkgs() {
	log info "Finding latest version of el-kernel-lts..."
	declare kernel_lts_tag="el9-6.1.y-generic"
	declare kernel_lts_release_api_url="https://api.github.com/repos/k8s-avengers/el-kernel-lts/releases/tags/${kernel_lts_tag}"
	declare kernel_lts_release_dl_url kernel_lts_fn

	find_one_kernel_lts_file "kernel_lts"
	kernel_file="${kernel_lts_fn}"
	kernel_url="${kernel_lts_release_dl_url}"

	find_one_kernel_lts_file "px"
	px_file="${kernel_lts_fn}"
	px_url="${kernel_lts_release_dl_url}"

	log info "kernel_file: ${kernel_file}"
	log info "kernel_url: ${kernel_url}"
	log info "px_file: ${px_file}"
	log info "px_url: ${px_url}"

	# lets write those to a file in WORK_DIR so downloader can reach it
	cat <<- KVERSIONS > "${WORK_DIR}/kversions.conf.sh"
		declare kernel_lts_tag="${kernel_lts_tag}"
		declare kernel_lts_release_api_url="${kernel_lts_release_api_url}"
		declare kernel_file="${kernel_file}"
		declare kernel_url="${kernel_url}"
		declare px_file="${px_file}"
		declare px_url="${px_url}"
	KVERSIONS

	cat "${WORK_DIR}/kversions.conf.sh"

	log info "Adding kernel lts packages to package list..."
	mkosi_config_add_rootfs_packages "kernel_lts_generic_61y" # simple name of the package; mkosi builds a temporary repo with the extra-packages in it
	mkosi_config_add_rootfs_packages "px"
}

function download_one_kernel_lts_file() {
	declare kernel_lts_release_dl_url kernel_lts_fn
	kernel_lts_release_dl_url="${1}"
	kernel_lts_fn="${2}"

	log info "Downloading kernel item  from ${kernel_lts_release_dl_url} to file /cache/extra/${kernel_lts_fn}"

	# Download and install the kernel
	if [[ -f "/cache/extra/${kernel_lts_fn}" ]]; then
		log info "Kernel item already downloaded; /cache/extra/${kernel_lts_fn}"
	else
		log info "Downloading kernel item '${kernel_lts_fn}'..."
		wget --no-check-certificate --local-encoding=UTF-8 --output-document="/cache/extra/${kernel_lts_fn}.tmp" "${kernel_lts_release_dl_url}"
		mv "/cache/extra/${kernel_lts_fn}.tmp" "/cache/extra/${kernel_lts_fn}"
		ls -lah "/cache/extra/${kernel_lts_fn}"
	fi

	# Add the package to the mkosi extra-packages directory, so it can be found by mkosi
	cp -v "/cache/extra/${kernel_lts_fn}" "extra-packages/${kernel_lts_fn}"
}

function find_one_kernel_lts_file() {
	kernel_lts_release_dl_url="$(curl -sL "${kernel_lts_release_api_url}" | jq . | grep "browser_download_url" | grep "/${1}" | grep -v -e "\-devel" -e "\-headers" | cut -d '"' -f 4)"
	kernel_lts_fn="${kernel_lts_release_dl_url##*/}"
}
