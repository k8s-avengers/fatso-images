#!/usr/bin/env bash

# Add the repo config to the skeketon tree, this way we capitalize on mkosi's caches
function config_mkosi_pre::epel_from_mirror() {
	log info "Adding EPEL from dl.fedoraproject.org mirror for EL release ${EL_RELEASE} "

	mkosi_stdin_to_work_file "package-manager-tree/etc/yum.repos.d" "epel-${EL_RELEASE}.repo" <<- EPEL_YUM_REPO_MIRROR
		[epel${EL_RELEASE}]
		name=epel${EL_RELEASE}
		baseurl=https://dl.fedoraproject.org/pub/epel/${EL_RELEASE}/Everything/x86_64/
		gpgcheck=1
		enabled=1
		gpgkey=https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-${EL_RELEASE}
	EPEL_YUM_REPO_MIRROR

	#cat "${WORK_DIR}/package-manager-tree/etc/yum.repos.d/epel-${EL_RELEASE}.repo"
}
