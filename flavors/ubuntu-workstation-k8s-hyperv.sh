#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu-workstation-k8s.sh"

FLAVOR_FRAGMENTS+=(
	"ubuntu/hyperv"
	"output_vhdx"
)
