#!/usr/bin/env bash

function config_mkosi_pre::ubuntu_grub() {
	declare -a pkgs=(
		"grub-efi"        # for EFI
		"grub-common"     # for grub-mkimage/update-grub etc
		"grub-ipxe"       # a simple way to have an iPXE fallback from grub menu
		"os-prober"       # for grub-mkconfig to detect other OSes
		"efibootmgr"      # for managing EFI boot entries / boot order etc
		"initramfs-tools" # should be brought in by kernel deps, but better to be explicit
	)
	mkosi_config_add_rootfs_packages "${pkgs[@]}"
}

function config_mkosi_post::ubuntu_grub() {
	mkosi_stdin_to_work_file "repart.grub" "00-esp.conf" <<- REPART_ESP # Use a large /boot (which is both the ESP and /boot; thanks, systemd-boot)
		[Partition]
		Type=esp
		Format=vfat
		CopyFiles=/boot:/
		CopyFiles=/efi:/
		SizeMinBytes=2048M
		SizeMaxBytes=2048M
	REPART_ESP

	mkosi_stdin_to_work_file "repart.grub" "10-root.conf" <<- REPART_ROOT
		[Partition]
		Type=root
		Format=ext4
		CopyFiles=/
		Minimize=off
		SizeMinBytes=8192M
		GrowFileSystem=on
	REPART_ROOT

	mkosi_conf_begin_edit "grub"
	mkosi_conf_config_value "Output" "RepartDirectories" "repart.grub" # defined above above
	mkosi_conf_config_value "Output" "Format" "disk"
	mkosi_conf_config_value "Content" "Bootable" "yes"
	mkosi_conf_config_value "Content" "Bootloader" "grub"
	mkosi_conf_config_value "Content" "UnifiedKernelImages" "no"

	# Trick: exclude all, include all == get _all_ modules in the initrd
	mkosi_conf_config_value "Content" "KernelModulesInitrdExclude" ".*"
	mkosi_conf_config_value "Content" "KernelModulesInitrdInclude" ".*"
	mkosi_conf_finish_edit "grub"

	# _also_ write the cmdline to the grub config (mkosi itself uses the KernelCommandLine= set by common_bootable)
	log info "Setting up GRUB config with kernel cmdline '${KERNEL_CMDLINE_FRAGMENTS[*]}'"
	mkosi_stdin_to_work_file "mkosi.extra/etc/default/grub.d" "50-simple.cfg" <<- GRUB_CONF_SIMPLE
		GRUB_CMDLINE_LINUX_DEFAULT="${KERNEL_CMDLINE_FRAGMENTS[*]}"
		GRUB_TIMEOUT_STYLE=menu
		GRUB_TIMEOUT=3
		GRUB_DISABLE_SUBMENU=y
		GRUB_DISABLE_OS_PROBER=false
		GRUB_GFXPAYLOAD=keep
	GRUB_CONF_SIMPLE

}

# Could easily move those to assets
function mkosi_script_postinst_chroot::grub_fixes() {
	# Disable trying to symlink the latest versions of kernel in /boot -- mkosi forces us to use a VFAT for /boot which doesnt support symlinks
	# This is only for allowing kernels to be upgraded. But these are supposed to be immutable. So really just a stopgap
	cat <<- EOD >> /etc/kernel-img.conf
		do_symlinks = no
		no_symlinks = yes
	EOD

	# Create a script to reboot the system in PXE mode again. # @TODO group this with k3s scripts and avoid the heredocs
	mkdir -p /usr/local/sbin
	cat <<- 'EOD' > /usr/local/sbin/pxe-boot-this
		#!/bin/bash
		set -e 
		declare pxe_efi_bootnum="$(efibootmgr | grep -e "IPV4" -e "EFI Network" | cut -d " " -f 1 | head -1 | sed -e 's/Boot//g' | sed -e 's/*//g')"
		echo "PXE bootnum: ${pxe_efi_bootnum}"
		efibootmgr --bootnext "${pxe_efi_bootnum}"
		sync
		echo "Rebooting in PXE mode in 2s..."
		sleep 2
		reboot -f
	EOD
	chmod +x /usr/local/sbin/pxe-boot-this

	# Create a script to restore grub normalcy @TODO idem
	mkdir -p /usr/local/sbin
	cat <<- 'EOD' > /usr/local/sbin/restore-grub-normalcy
		#!/bin/bash
		set -e
		rm -rf /boot/ubuntu /boot/loader /boot/EFI
		mkdir -p /boot/EFI
		update-initramfs -k all -c
		grub-install --efi-directory /boot --bootloader-id=fatso 
		update-grub
	EOD
	chmod +x /usr/local/sbin/restore-grub-normalcy

	# Configure for (not used in image, but for later runtime)
	cat <<- 'EOD' > /etc/initramfs-tools/initramfs.conf
		MODULES=most
		BUSYBOX=auto
		COMPRESS=zstd
		DEVICE=
		NFSROOT=auto
		RUNSIZE=10%
		FSTYPE=ext4
	EOD

}
