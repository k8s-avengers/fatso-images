#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu-cloud.sh"

FLAVOR_FRAGMENTS+=(
	"ubuntu/k8s-worker-containerd"
	"apt/k8s"
)
