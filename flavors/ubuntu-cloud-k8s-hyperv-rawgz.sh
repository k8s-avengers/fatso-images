#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu-cloud-k8s.sh"

# A strange combo, but useful: hyperv-daemons, but in .img.gz format; useful for simulating baremetal provisioning on Hyper-V virtual machines, etc.
FLAVOR_FRAGMENTS+=(
	"ubuntu/hyperv"
	"output_rawgz"
)
