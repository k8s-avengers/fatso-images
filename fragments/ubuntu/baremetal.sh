#!/usr/bin/env bash

function config_mkosi_pre::ubuntu_baremetal() {
	declare -a pkgs=(
		"fwupd"           # for firmware updates
		"fwupd-unsigned"  # for UEFI capsule firmware updates
		"hwdata"          # for hardware database
		"linux-firmware"  # for most firmware one might want (free-ish)
		"amd64-microcode" # for AMD CPU microcode updates
		"intel-microcode" # for Intel CPU microcode updates
		"pciutils"        # for lspci
		"usbutils"        # for lsusb
		"sg3-utils-udev"  # for scsi udev support
		"dmidecode"       # for reading DMI/SMBIOS data
		"lm-sensors"      # for reading hw sensors (temperature etc)
	)
	mkosi_config_add_rootfs_packages "${pkgs[@]}"
}
