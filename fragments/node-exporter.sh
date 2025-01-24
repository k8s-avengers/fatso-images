function mkosi_script_postinst_chroot::deploy_node_exporter() {
	declare version="1.8.1"
	declare arch="amd64"

	log info "Setup Node Exporter version ${version} for arch ${arch}..."

	# ewww, this stinks
	declare down_url="https://github.com/prometheus/node_exporter/releases/download/v${version}/node_exporter-${version}.linux-${arch}.tar.gz"
	declare extract_base_dir="/tmp/node_exporter_${version}"
	mkdir -p "${extract_base_dir}"
	declare down_file="/${extract_base_dir}/node_exporter-${version}.linux-${arch}.tar.gz"
	declare tmp_extract_dir="/tmp/node_exporter_${version}/node_exporter-${version}.linux-${arch}"
	declare tmp_bin="${tmp_extract_dir}/node_exporter"
	declare dst_bin="/usr/local/sbin/node_exporter"
	wget --no-check-certificate --progress=dot:mega -O "${down_file}" "${down_url}"
	cd "${extract_base_dir}" || log error "Failed to cd to ${extract_base_dir}"
	tar xzf "${down_file}"
	cp -v "${tmp_bin}" "${dst_bin}"
	cd - || log error "Failed to cd back"
	rm -rf "${extract_base_dir}"

	create_simple_systemd_service "node-exporter" <<- EOD
		[Unit]
		Description=Prometheus Node Exporter ${version}
		After=network-online.target
		[Service]
		User=root
		ExecStart=${dst_bin} --collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/.+)(\$|/) --collector.filesystem.ignored-fs-types=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)\$
		RestartSec=120
		Restart=on-failure
		[Install]
		WantedBy=multi-user.target
	EOD

	log info "Done, node exporter deployed as systemd service."
}

function mkosi_script_finalize_chroot::node_exporter_enable() {
	log info "Enabling node-exporter service..."
	systemctl enable node-exporter
}

function mkosi_script_finalize_chroot::node_exporter_show_version() {
	log info "Checking node-exporter version..."
	/usr/local/sbin/node_exporter --version
}

# @TODO: refactor this into common or something
function create_simple_systemd_service() {
	declare APP_ID=$1
	declare SERVICE_NAME=${APP_ID}.service
	declare SERVICE_UNIT=/etc/systemd/system/${SERVICE_NAME}
	log info "Creating systemd service ${SERVICE_NAME} in ${SERVICE_UNIT}..."
	cat > "${SERVICE_UNIT}" # Now create a systemd service with the contents of stdin
	log info "Created service ${SERVICE_NAME} in ${SERVICE_UNIT}..."
}
