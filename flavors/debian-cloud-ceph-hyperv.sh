#!/usr/bin/env bash

source "${FLAVOR_DIR}/debian-cloud-ceph.sh"

FLAVOR_FRAGMENTS+=(
	"debian/hyperv"  # hyperv support packages included in rootfs
	"output_vhdx" # output as VHDX
)
