#!/bin/bash
set -e

set -e # stop on errors

# if first argument unset, bail
[[ -z "${1}" ]] && echo "Usage: $0 <k3s-server-ip>" && exit 1

# Ensure /usr/local/bin is first in PATH
export PATH="/usr/local/bin:${PATH}"

export DEBIAN_FRONTEND=noninteractive

declare K3S_CLUSTER_NAME="${K3S_CLUSTER_NAME:-"$(hostname)"}"

# Grab some networking info
declare net_interface net_ipv4_gateway net_ipv4_addr
net_interface="$(ip -4 route get 8.8.8.8 | grep via | cut -d " " -f 5 | xargs echo -n)"
echo "Determined net_interface: ${net_interface}" >&2
net_ipv4_gateway="$(ip -4 route get 8.8.8.8 | grep via | cut -d " " -f 3 | xargs echo -n)"
net_ipv4_addr="$(ip -4 addr s dev "${net_interface}" | grep "scope global .* ${net_interface}" | tr -s " " | cut -d " " -f 3 | xargs echo -n | cut -d "/" -f 1)"
echo "Determined net_ipv4_gateway: ${net_ipv4_gateway}" >&2
echo "Determined net_ipv4_addr: ${net_ipv4_addr}" >&2

# Install some packages
declare -a pkgs_to_install=()
[[ ! -f /usr/sbin/iptables-save ]] && pkgs_to_install+=("iptables")
[[ ! -f /usr/bin/jq ]] && pkgs_to_install+=("jq")
[[ ! -f /usr/bin/nano ]] && pkgs_to_install+=("nano")
[[ ! -f /usr/bin/tree ]] && pkgs_to_install+=("tree")
[[ ! -f /usr/bin/wget ]] && pkgs_to_install+=("wget")
[[ ! -f /usr/bin/git ]] && pkgs_to_install+=("git")

# Install packages if array is not empty
if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
	echo "Installing packages: ${pkgs_to_install[*]}" >&2
	apt -y install "${pkgs_to_install[@]}"
fi

# Get the current kernel's major version
declare -i current_kernel_major_version
current_kernel_major_version=$(uname -r | cut -d '.' -f 1)

# If not at least 6, install el-kernel-lts from k8s-avengers's repo
if [[ ${current_kernel_major_version} -lt 6 ]]; then
	echo "Unsupported kernel version ${current_kernel_major_version}" >&2
	exit 1
fi

# Config for k3s install
mkdir -p /etc/rancher/k3s/config.yaml.d
cat <<- K3S_MAIN_CONFIG > /etc/rancher/k3s/config.yaml.d/install_config.yaml
	node-label:
	  - "foo=bar"
	  - "something=joined"
K3S_MAIN_CONFIG

# Array for cmdline opts
declare k3s_cmdline_opts=()

k3s_cmdline_opts+=("--server" "https://${1}:6443") # join cluster
# k3s_cmdline_opts+=("--tls-san=${net_ipv4_addr}") # heh? why?
# Those gotta match the original master deployment
k3s_cmdline_opts+=("--disable-network-policy" "--flannel-backend=none") # Disable k3s's own CNI and policy stuff
k3s_cmdline_opts+=("--disable=traefik")
k3s_cmdline_opts+=("--disable-kube-proxy") # for cilium's replacement
k3s_cmdline_opts+=("--disable=servicelb")

# Install k3s using the standalone script
echo "Installing k3s '${k3s_cmdline_opts[*]}'" >&2
curl -sfL https://get.k3s.io | K3S_TOKEN=SECRET sh -s - "${k3s_cmdline_opts[@]}"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
