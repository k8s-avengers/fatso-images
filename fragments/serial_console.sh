#!/usr/bin/env bash

function config_mkosi_pre::serial_console() {
	log warn "Enabling serial console on ttyS0"
	KERNEL_CMDLINE_FRAGMENTS+=("console=ttyS0")
}
