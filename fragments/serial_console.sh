#!/usr/bin/env bash

function config_mkosi_pre::serial_console() {
	log warn "Enabling serial console..."
	case "${OS_ARCH}" in
		"amd64")
			log info "Enabling serial console on ttyS0 for x86_64"
			KERNEL_CMDLINE_FRAGMENTS+=("console=ttyS0")
			;;
		"arm64")
			log info "Enabling serial console on ttyAMA0 for aarch64"
			KERNEL_CMDLINE_FRAGMENTS+=("console=ttyAMA0")
			;;
		*)
			log error "Unsupported architecture '${OS_ARCH}' for serial console configuration."
			exit 1
			;;
	esac
}
