#!/usr/bin/env bash

# @TODO: this needs a major rethink; we should have scripts that run inside Docker, but before mkosi, that prepares the .deb
#        and passes it via
#        BuildSources=../my-packages:my-packages-in-sandbox
#        Packages=my-packages-in-sandbox/abc.rpm
# For now, it will re-download the .deb everytime image is built :-|

function mkosi_script_postinst_chroot::400_k8s_worker_containerd_install() {
	#### k8s stuff
	## containerd; using a prebuilt deb with many necessary tools in k8s-worker-containerd
	# @TODO slim down a copy of this (no cfssl needed, etc)

	declare latest_release_version
	latest_release_version=$(curl -sL "https://api.github.com/repos/armsurvivors/k8s-worker-containerd/releases/latest" | jq -r '.tag_name')

	declare deb_file down_url down_dir full_deb_path
	deb_file="k8s-worker-containerd_amd64_noble.deb"
	down_url="https://github.com/armsurvivors/k8s-worker-containerd/releases/latest/download/${deb_file}"
	down_dir="/root/k8s-worker-containerd"
	mkdir -p "${down_dir}"
	full_deb_path="${down_dir}/${latest_release_version}_${deb_file}"

	echo "Will download ${full_deb_path} from latest release..."
	wget --progress=dot:mega --local-encoding=UTF-8 --output-document="${full_deb_path}.tmp" "${down_url}"
	mv -v "${full_deb_path}.tmp" "${full_deb_path}"

	apt -y install "${full_deb_path}"
	rm -v "/${full_deb_path}"

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
