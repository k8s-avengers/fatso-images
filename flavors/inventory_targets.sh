#!/usr/bin/env bash

# "Target"s possible:
# "baremetal" - implies an .img.gz output file, and fragments adding firmware and drivers, etc.
# "hyperv" - implies vhdx output file , and fragments adding the hyperv-daemons and such
# "qemu" - implies qcow2 output file, and fragments adding the qemu-guest-agent and such
# "hyperv-rawgz"; implies .img.gz output file, and fragments adding the hyperv-daemons and such

function flavor_target_baremetal() {
	FLAVOR_FRAGMENTS+=("output_rawgz")
	case "${FLAVOR_DISTRO_TYPE}" in
		"apt") FLAVOR_FRAGMENTS+=("${FLAVOR_DISTRO}/baremetal") ;; # Varies per-distro
		"el") FLAVOR_FRAGMENTS+=("el/baremetal") ;;                # Common across all EL
		*) log warn "Unknown FLAVOR_DISTRO_TYPE: ${FLAVOR_DISTRO_TYPE} for baremetal target" ;;
	esac
}

function flavor_target_hyperv() {
	FLAVOR_FRAGMENTS+=("output_vhdx")
	case "${FLAVOR_DISTRO_TYPE}" in
		"apt") FLAVOR_FRAGMENTS+=("${FLAVOR_DISTRO}/hyperv") ;; # Varies per-distro
		"el") FLAVOR_FRAGMENTS+=("el/hyperv") ;;                # Common across all EL
		*) log warn "Unknown FLAVOR_DISTRO_TYPE: ${FLAVOR_DISTRO_TYPE} for hyperv target" ;;
	esac
}

function flavor_target_hyperv-rawgz() {
	FLAVOR_FRAGMENTS+=("output_rawgz")
	case "${FLAVOR_DISTRO_TYPE}" in
		"apt") FLAVOR_FRAGMENTS+=("${FLAVOR_DISTRO}/hyperv") ;; # Varies per-distro
		"el") FLAVOR_FRAGMENTS+=("el/hyperv") ;;                # Common across all EL
		*) log warn "Unknown FLAVOR_DISTRO_TYPE: ${FLAVOR_DISTRO_TYPE} for hyperv-rawgz target" ;;
	esac
}

function flavor_target_qemu() {
	FLAVOR_FRAGMENTS+=("output_qcow2")
	FLAVOR_FRAGMENTS+=("apt/qemu-guest-agent") # This just adds the qemu-guest-agent package, which is the same across EL/Debian/Ubuntu
}
