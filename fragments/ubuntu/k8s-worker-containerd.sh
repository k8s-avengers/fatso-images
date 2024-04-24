#!/usr/bin/env bash

# This runs outside of mkosi, but inside the Docker container.
function mkosi_script_pre_mkosi_host::k8s_worker_containerd_download() {
	log info "Downloading k8s-worker-containerd package..." # @TODO slim down a copy of this (no cfssl needed, etc) - its huge

	declare latest_release_version
	latest_release_version=$(curl -sL "https://api.github.com/repos/armsurvivors/k8s-worker-containerd/releases/latest" | jq -r '.tag_name')

	log info "Downloading k8s-worker-containerd package of version '${latest_release_version}'..."

	declare deb_file down_url down_dir full_deb_path
	deb_file="k8s-worker-containerd_amd64_noble.deb"
	down_url="https://github.com/armsurvivors/k8s-worker-containerd/releases/latest/download/${deb_file}"
	down_dir="/cache/extra"
	mkdir -p "${down_dir}"
	full_deb_path="${down_dir}/${latest_release_version}_${deb_file}"

	if [[ -f "${full_deb_path}" ]]; then
		log info "Package already downloaded: ${full_deb_path}"
	else
		log info "Will download ${full_deb_path} from latest release..."
		wget --progress=dot:mega --local-encoding=UTF-8 --output-document="${full_deb_path}.tmp" "${down_url}"
		mv -v "${full_deb_path}.tmp" "${full_deb_path}"
	fi

	# Add the package to the mkosi extra-packages directory, so it can be found by mkosi
	# Do NOT include the version, so it can always be referred to by the same name
	# Those functions run in very different contexts, so we can't just pass the path around.
	cp -v "${full_deb_path}" "extra-packages/${deb_file}"
}

function config_mkosi_pre::k8s_worker_containerd_package() {
	mkosi_config_add_rootfs_packages "./extra-packages/k8s-worker-containerd_amd64_noble.deb"
}

function mkosi_script_postinst_chroot::400_k8s_worker_containerd_install() {
	# Check by running it under chroot
	containerd --version

	# Enable its systemd service
	systemctl enable containerd.service

	# Configure containerd to use systemd cgroup driver
	mkdir -p /etc/containerd
	containerd config default > /etc/containerd/config.toml

	# Keep a copy of the original config
	cp -v /etc/containerd/config.toml /etc/containerd/config.toml.orig

	# Manipulating .toml in bash is even worse than YAML. This should NOT be done here.
	if grep -q SystemdCgroup /etc/containerd/config.toml; then
		# If it's already there make sure it's on
		sed -i -e 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
	else
		# Terrible hack to add SystemdCgroup.
		sed -i -e 's/runtimes.runc.options]/runtimes.runc.options]\n            SystemdCgroup = true/' /etc/containerd/config.toml
	fi

	echo "Config cri-tools to use containerd..."
	cat <<- EOD > /etc/crictl.yaml
		runtime-endpoint: unix:///var/run/containerd/containerd.sock
	EOD
}
