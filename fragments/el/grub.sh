#!/usr/bin/env bash

function config_mkosi_pre::el_grub() {
	mkosi_conf_begin_edit "el_grub"
	mkosi_conf_config_value "Output" "Format" "disk"
	mkosi_conf_config_value "Content" "Bootable" "yes"
	mkosi_conf_config_value "Content" "Bootloader" "grub"
	mkosi_conf_config_value "Content" "UnifiedKernelImages" "no"
	# Trick: exclude all, include all == get _all_ modules in the initrd
	mkosi_conf_config_value "Content" "KernelModulesInitrdExclude" ".*"
	mkosi_conf_config_value "Content" "KernelModulesInitrdInclude" ".*"
	mkosi_conf_finish_edit "el_grub"

	declare -g -a KERNEL_CMDLINE_FRAGMENTS
	KERNEL_CMDLINE_FRAGMENTS+=("rw" "console=tty1" "selinux=0") # @TODO selinux should not be done here

	log info "Grub: Image Architecture: OS_ARCH: ${OS_ARCH}, TOOLCHAIN_ARCH: ${TOOLCHAIN_ARCH}"
	mkosi_config_add_rootfs_packages grubby grub2-tools grub2-tools-extra # Common across architectures
	mkosi_config_add_rootfs_packages "e2fsprogs" # needed for ext4 rootfs

	case "${OS_ARCH}" in
		"amd64")
			log info "Grub: Adding x86-64 specific packages"
			mkosi_config_add_rootfs_packages grub2-efi-x64 grub2-efi-x64-modules grub2-tools-efi
			;;
		"arm64")
			log info "Grub: Adding aarch64 specific packages"
			mkosi_config_add_rootfs_packages grub2-efi-aa64 grub2-efi-aa64-modules
			;;
		*)
			log error "Unsupported architecture '${OS_ARCH}' for GRUB configuration."
			exit 1
			;;
	esac
}

function config_mkosi_post::el_grub_ext4_repart() {
	log info "grub: configuring repart to use ext4 rootfs and larger boot/ESP"

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

	# Handled by common_base
	log warn "Setting up mkosi to use ext4 without orphan_file"
	MKOSI_CONTENT_ENVIRONMENT["SYSTEMD_REPART_MKFS_OPTIONS_EXT4"]="-O ^orphan_file"

	mkosi_conf_begin_edit "grub"
	mkosi_conf_config_value "Output" "RepartDirectories" "repart.grub" # defined above above
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
