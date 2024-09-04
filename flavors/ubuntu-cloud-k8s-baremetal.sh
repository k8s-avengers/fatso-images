#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu-cloud-k8s.sh"

FLAVOR_FRAGMENTS+=(
	"ubuntu/baremetal"
	"output_rawgz"
)
