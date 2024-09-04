#!/usr/bin/env bash

source "${FLAVOR_DIR}/ubuntu-cloud-k8s-baremetal.sh"

FLAVOR_FRAGMENTS+=(
	"ubuntu/k3s" # won't hurt; only deploys scripts

	"ubuntu/nvidia"
	"ubuntu/nvidia-container" # requires k8s-worker-containerd and nvidia
)
