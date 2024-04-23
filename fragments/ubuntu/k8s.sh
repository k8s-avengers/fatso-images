#!/usr/bin/env bash

# @TODO mkosi hasn't good support for adding external repos, skeleton trees are needed, create a helper for this
function config_mkosi_pre::k8s() {
	mkosi_conf_begin_edit "k8spkgman"
	mkosi_conf_config_value "Distribution" "PackageManagerTrees" "package-manager/apt-k8s" # @TODO this is a list of trees actually
	mkosi_conf_finish_edit "k8spkgman"

	declare K8S_MAJOR_MINOR="1.28"
	log warn "Adding k8s binaries version ${K8S_MAJOR_MINOR}"

	mkosi_stdin_to_work_file "package-manager/apt-k8s/etc/apt/sources.list.d" "kubernetes.list" <<- SOURCES_LIST_K8S
		deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR}/deb/ /
	SOURCES_LIST_K8S

	# This ends up running in the host, of course, so gpg & curl need to be available # @TODO: maybe in a config script?
	mkdir -p "${WORK_DIR}/package-manager/apt-k8s/etc/apt/keyrings"
	curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_MAJOR_MINOR}/deb/Release.key" | gpg --dearmor -o "${WORK_DIR}/package-manager/apt-k8s/etc/apt/keyrings/kubernetes-apt-keyring.gpg"

	mkosi_config_add_rootfs_packages "kubeadm" "kubelet" "kubectl"
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
