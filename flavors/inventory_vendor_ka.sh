#!/usr/bin/env bash

# A no-vendor vendor; just the base stuff. 'standard' is handled specially.
function flavor_vendor_standard() {
	:
}

function flavor_vendor_ka() {
	FLAVOR_FRAGMENTS+=(
		"serial_console"
		"registry_mirrors_sample"
	)

	case "${FLAVOR_DISTRO_TYPE}" in
		"apt") FLAVOR_FRAGMENTS+=("apt/ssh-import-id") ;; # Only deb-based distros have this
	esac
}
