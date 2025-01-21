#!/usr/bin/env bash

# Add the repo config to the skeketon tree, this way we capitalize on mkosi's caches
function config_mkosi_pre::powershell_from_microsoft() {
	log info "Adding Powershell from Microsoft RPM repo for EL release ${EL_RELEASE} "

	mkosi_stdin_to_work_file "package-manager-tree/etc/yum.repos.d" "ms-powershell-${EL_RELEASE}.repo" <<- POWERSHELL_REPO
		[microsoft-powershell-el-${EL_RELEASE}]
		name=microsoft-powershell-el-${EL_RELEASE}
		baseurl=https://packages.microsoft.com/rhel/${EL_RELEASE}.0/prod
		enabled=1
		gpgcheck=0
		gpgkey=https://packages.microsoft.com/keys/microsoft.asc
	POWERSHELL_REPO

	mkosi_config_add_rootfs_packages powershell
}

function mkosi_script_finalize_chroot::powershell_show_version() {
	log info "Checking Powershell version..."
	pwsh --version
}
