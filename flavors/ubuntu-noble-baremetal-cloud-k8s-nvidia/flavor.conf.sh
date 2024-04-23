#!/usr/bin/env bash

# Config file for flavor

declare -g -r BUILDER="ubuntu"
declare -g -r BUILDER_CACHE_PKGS_ID="ubuntu-noble"

declare -g -r -a FLAVOR_FRAGMENTS=(
	"common_base.sh"
	"ubuntu/base.sh"
	"ubuntu/ssh.sh"
	"ubuntu/grub.sh"
	"ubuntu/baremetal.sh"
	"ubuntu/cloud.sh"
	"ubuntu/k8s-worker-containerd.sh"
	"ubuntu/k8s.sh"
	#"ubuntu/k3s.sh" # maybe just for workstation flavor, no server wants this crap
	"ubuntu/nvidia.sh"
)
