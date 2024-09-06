#!/usr/bin/env bash

# A no-vendor vendor; just the base stuff. 'standard' is handled specially.
function flavor_vendor_standard() {
	:
}

function flavor_vendor_ka() {
	FLAVOR_FRAGMENTS+=(
		"serial_console"
		"apt/ssh-import-id"
		"registry_mirrors_sample"
	)
}
