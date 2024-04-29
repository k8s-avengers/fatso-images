#!/usr/bin/env bash

# Config file for flavor

declare -g -r BUILDER="ubuntu"
declare -g -r BUILDER_CACHE_PKGS_ID="ubuntu-noble"

declare -g -a FLAVOR_FRAGMENTS=(
	"common_base"
	"common_bootable"

	"ubuntu/hyperv"
	"output_vhdx"

	"ubuntu/base"
	"ubuntu/ssh"
	"ubuntu/grub"
	"ubuntu/networkmanager"
	"ubuntu/wifi"
)
