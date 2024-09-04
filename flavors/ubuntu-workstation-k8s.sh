#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu-workstation.sh"

FLAVOR_FRAGMENTS+=(
	"ubuntu/k8s-worker-containerd"
	"apt/k8s"

	"ubuntu/k3s" # For workstations, also include the k3s fragments. It's just a bunch of scripts.
)
