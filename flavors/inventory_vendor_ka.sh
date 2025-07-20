#!/usr/bin/env bash

# A no-vendor vendor; just the base stuff. 'standard' is handled specially.
function flavor_vendor_standard() {
	:
}

# k8s-avengers vendor flavor. do NOT use these in production!
function flavor_vendor_ka() {

	function config_mkosi_init::predictable_image_names_sans_version() {
		log warn "Using predictable dist image name: '${FLAVOR}_${OS_ARCH}'"
		MKOSI_CONTENT_ENVIRONMENT["IMAGE_FLAVOR_VERSION_ID"]="${FLAVOR}_${OS_ARCH}"
	}

	FLAVOR_FRAGMENTS+=("serial_console") # Enable ttyS0 serial console

	case "${FLAVOR_DISTRO_TYPE}" in
		"apt") # Only deb-based distros have this
			function config_mkosi_pre::ssh_import_id() {
				log warn "Enabling ssh-import-id and a hardcoded SSH public key - DO NOT use in production"
				mkosi_config_add_rootfs_packages "ssh-import-id" #"python3-launchpadlib"
			}

			function mkosi_script_postinst_chroot::ssh_keys() {
				log warn "Enabling ssh-import-id and a hardcoded SSH public key - DO NOT use in production"
				ssh-import-id gh:rpardini
			}
			;;
	esac
}
