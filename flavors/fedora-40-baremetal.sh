#!/usr/bin/env bash

# Config file for flavor

declare -g -r BUILDER="fedora"
declare -g -r BUILDER_CACHE_PKGS_ID="fedora-40"

declare -g -r EL_DISTRO="fedora"
declare -g -r EL_RELEASE="40"
declare -g -r EL_REPOSITORIES="" # Fedora doesn't need EPEL -- EPEL _comes_ from fedora main repo

declare -g -a FLAVOR_FRAGMENTS=(
	"common_base"
	"common_bootable"
	"el/dnf"
	"el/el9_base"
	"el/el_fedora_base"
	"el/grub"
	"el/networkmanager"
	"el/k8s-containerd" # From Fedora's own repo -- NOT Docker's
	"el/k8s"
	"el/cloud"
)
