#!/usr/bin/env bash

source "${FLAVOR_DIR}/debian-cloud-ceph.sh"

FLAVOR_FRAGMENTS+=(
	"debian/baremetal"
	"output_rawgz"
)
