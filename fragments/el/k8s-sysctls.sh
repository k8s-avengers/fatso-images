function mkosi_script_postinst_chroot::configure_sysctl_inotify_limits() {
	log info "Configuring sysctl inotify limits for k8s/containerd..."

	cat <<- INOTIFY_SYSCTL_LIMITS > /etc/sysctl.d/99-el-k8s-sysctls.conf
		fs.inotify.max_user_instances = 8192
		fs.inotify.max_user_watches = 384171
	INOTIFY_SYSCTL_LIMITS

	log info "Configuring sysctl ipv4/ipv6 forwarding..."
	cat <<- IP_FORWARDING_SYSCTL > /etc/sysctl.d/99-el-k8s-ip-forward.conf
		net.bridge.bridge-nf-call-iptables = 1
		net.ipv4.ip_forward                = 1
		net.bridge.bridge-nf-call-iptables = 1
	IP_FORWARDING_SYSCTL
}
