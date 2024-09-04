#!/usr/bin/env bash

declare -g -r BUILDER="ubuntu"
declare -g -r BUILDER_CACHE_PKGS_ID="ubuntu-noble"

declare -g -a FLAVOR_FRAGMENTS=(
	"common_base"
	"common_bootable"

	"apt/base"
	"ubuntu/base"

	"apt/ssh"
	"apt/grub"
)
