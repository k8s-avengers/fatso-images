function config_mkosi_pre::ado_agent_prerequisite_packages() {
	mkosi_config_add_rootfs_packages "git"
}

function mkosi_script_postinst_chroot::deploy_latest_ado_agent() {
	log info "Obtaining latest ADO agent from Microsoft's GitHub..."
	declare version="4.248.0"
	declare tarball_fn="vsts-agent-linux-x64-${version}.tar.gz"
	declare down_url="https://vstsagentpackage.azureedge.net/agent/${version}/${tarball_fn}"
	declare tarball_path="/tmp/${tarball_fn}"
	declare agent_dir="/opt/vsts-agent"
	wget --no-check-certificate -O "${tarball_path}" "${down_url}"
	# extract the tarball to the agent_dir
	mkdir -p "${agent_dir}"
	tar -C "${agent_dir}" -xzf "${tarball_path}"
	rm -f "${tarball_path}"
	log info "ADO agent extracted to ${agent_dir}"
	return 0
}
