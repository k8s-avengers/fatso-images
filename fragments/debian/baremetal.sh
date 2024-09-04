#!/usr/bin/env bash

function config_mkosi_pre::debian_baremetal() {
	declare -a pkgs=(
		"firmware-linux"  # both free and nonfree
		"fwupd"           # for firmware updates
		"fwupd-unsigned"  # for UEFI capsule firmware updates
		"hwdata"          # for hardware database
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
