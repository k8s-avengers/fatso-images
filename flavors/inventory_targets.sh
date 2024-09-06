#!/usr/bin/env bash

# "Target"s possible:
# "baremetal" - implies an .img.gz output file, and fragments adding firmware and drivers, etc.
# "hyperv" - implies vhdx output file , and fragments adding the hyperv-daemons and such
# "qemu" - implies qcow2 output file, and fragments adding the qemu-guest-agent and such
# "hyperv-rawgz"; implies .img.gz output file, and fragments adding the hyperv-daemons and such

function flavor_target_baremetal() {
	FLAVOR_FRAGMENTS+=(
		"${FLAVOR_DISTRO}/baremetal" # this varies depending on the base flavor....?
		"output_rawgz"
	)
}

function flavor_target_hyperv() {
	FLAVOR_FRAGMENTS+=(
		"${FLAVOR_DISTRO}/hyperv" # hyperv support packages included in rootfs
		"output_vhdx"             # output as VHDX
	)
}

function flavor_target_qemu() {
	FLAVOR_FRAGMENTS+=(
		"apt/qemu-guest-agent" # qemu support packages included in rootfs
		# "output_qcow2"   # output as qcow2 # @TODO not implemented yet
	)
}

function flavor_target_hyperv-rawgz() {
	FLAVOR_FRAGMENTS+=(
		"${FLAVOR_DISTRO}/hyperv" # hyperv support packages included in rootfs
		"output_rawgz"            # output as .img.gz
	)
}
