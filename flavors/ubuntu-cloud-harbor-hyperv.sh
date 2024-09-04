#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu-cloud-harbor.sh"

FLAVOR_FRAGMENTS+=(
	"ubuntu/hyperv"
	"output_vhdx"
)
