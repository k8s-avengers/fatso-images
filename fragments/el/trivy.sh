#!/usr/bin/env bash

function config_mkosi_pre::el_trivy_via_repo() {
	log info "Adding Trivy from Aquasecurity RPM repo..."

	mkosi_stdin_to_work_file "package-manager-tree/etc/yum.repos.d" "trivy.repo" <<- TRIVY_REPO
		[trivy]
		name=Trivy repository
		baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/\$basearch/
		gpgcheck=1
		enabled=1
		gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key
	TRIVY_REPO

	mkosi_config_add_rootfs_packages trivy
}

## This saves the DB into a .cache folder, per user; do it in cloud-init, not here.
#function mkosi_script_finalize_chroot::el_trivy_update_db() {
#	log info "Updating Trivy vulnerability databases..."
#	trivy image --download-db-only
#}

function mkosi_script_finalize_chroot::el_trivy_show_version() {
	log info "Checking Trivy version..."
	trivy --version
}
