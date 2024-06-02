#!/usr/bin/env bash

# Oops, a global variable!
declare -g -r K8S_MAJOR_MINOR="1.28"

# Add the repo config to the skeketon tree, and mark the pkgs to be installed; this way we capitalize on mkosi's caches
function config_mkosi_pre::k8s() {
	log info "Adding k8s binaries version ${K8S_MAJOR_MINOR}"

	mkosi_stdin_to_work_file "package-manager-tree/etc/apt/sources.list.d" "kubernetes.list" <<- SOURCES_LIST_K8S
		deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR}/deb/ /
	SOURCES_LIST_K8S

	mkosi_config_add_rootfs_packages "kubeadm" "kubelet" "kubectl"
}

# This runs _outside_ of mkosi, but inside the docker container, directly in the WORK_DIR; just add files there
function mkosi_script_pre_mkosi_host::k8s_apt_keyring() {
	log info "Adding k8s apt-key version ${K8S_MAJOR_MINOR}"
	mkdir -p "package-manager-tree/etc/apt/keyrings"
	curl -fsSL -k "https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR}/deb/Release.key" | gpg --dearmor -o "package-manager-tree/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
}

function mkosi_script_postinst_chroot::502_k8s_install() {
	log info "Deployed kubeadm version: $(kubeadm version)"
	systemctl enable kubelet.service # let kubelet bootloop for kubeadm's benefit

	# Hold the k8s packages
	apt-mark hold kubeadm kubelet kubectl
}

function mkosi_script_postinst_chroot::505_k8s_config() {
	### k8s-related settings
	# @TODO: dubious and probably better left to cloud-init to decide, but generally needed for a bare capi demo

	echo "Configuring systemd-network to not interefere with Cilium..."
	# https://docs.cilium.io/en/stable/operations/system_requirements/#systemd-based-distributions
	cat <<- EOD > /etc/systemd/networkd.conf
		[Network]
		ManageForeignRoutes=no
		ManageForeignRoutingPolicyRules=no
	EOD

	echo "Module br_netfilter ..."
	cat <<- EOF > /etc/modules-load.d/k8s.conf
		br_netfilter
	EOF

	echo "Tuning bridge-nf-call-iptables/ip6tables in sysctl..."
	cat <<- EOF > /etc/sysctl.d/k8s.conf
		net.bridge.bridge-nf-call-iptables = 1
		net.bridge.bridge-nf-call-ip6tables = 1
		net.ipv4.ip_forward = 1
		net.ipv6.conf.all.forwarding = 1
		net.ipv6.conf.all.disable_ipv6 = 0
		net.ipv4.tcp_congestion_control = bbr
		vm.overcommit_memory = 1
		kernel.panic = 10
		kernel.panic_on_oops = 1
		fs.inotify.max_user_instances = 524288
		fs.inotify.max_user_watches = 524288
	EOF

}
