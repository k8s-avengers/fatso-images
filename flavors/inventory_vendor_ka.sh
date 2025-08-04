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
		"el")
			log warn "@TODO test for ssh-import-id via Python 3 pip"
			FLAVOR_FRAGMENTS+=("ka/el_ssh_keys")
			;;

		"apt")
			FLAVOR_FRAGMENTS+=("ka/apt_ssh_keys")
			;;
	esac
}
