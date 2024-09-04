#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu-workstation-k8s.sh"

FLAVOR_FRAGMENTS+=(
	"ubuntu/baremetal"
	"output_rawgz"

	# For bare metal, it makes sense to have Wifi support for workstations
	"apt/wifi"
)
