#!/usr/bin/env bash

# Add the repo config to the skeketon tree, this way we capitalize on mkosi's caches
function config_mkosi_pre::azure_cli_from_microsoft() {
	log info "Adding Azure CLI from Microsoft RPM repo for EL release ${EL_RELEASE} "

	mkosi_stdin_to_work_file "package-manager-tree/etc/yum.repos.d" "ms-azure_cli-${EL_RELEASE}.repo" <<- AZURE_CLI_REPO
		[microsoft-azure-cli-el-${EL_RELEASE}]
		name=microsoft-azure-cli-el-${EL_RELEASE}
		baseurl=https://packages.microsoft.com/rhel/${EL_RELEASE}.0/prod
		enabled=1
		gpgcheck=0
		gpgkey=https://packages.microsoft.com/keys/microsoft.asc
	AZURE_CLI_REPO

	mkosi_config_add_rootfs_packages azure-cli
}

# This doesnt make sense, as it downloads & installs for the current user (root) only.
#function mkosi_script_postinst_chroot::azure_cli_add_devops_extension() {
#	log info "Adding Azure DevOps extension to Azure CLI..."
#	az extension add --name azure-devops
#}

function mkosi_script_finalize_chroot::azure_cli_show_version() {
	log info "Checking Azure CLI version..."
	az --version
}
