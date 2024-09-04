#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu-cloud-ceph.sh"

FLAVOR_FRAGMENTS+=(
	"ubuntu/hyperv"
	"output_vhdx"
)
