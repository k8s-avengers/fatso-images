#!/usr/bin/env bash

# Helper function, used both outside and inside of mkosi context
function obtain_latest_version_k8s_worker_containerd() {
	declare -g latest_release_version_k8s_worker_containerd
	latest_release_version_k8s_worker_containerd=$(curl -sL "https://api.github.com/repos/armsurvivors/k8s-worker-containerd/releases/latest" | jq -r '.tag_name')

	log info "Determined k8s-worker-containerd latest version '${latest_release_version_k8s_worker_containerd}'..."
}

# This runs outside of mkosi, but inside the Docker container.
function mkosi_script_pre_mkosi_host::k8s_worker_containerd_download() {
	log info "Downloading k8s-worker-containerd package..." # @TODO slim down a copy of this (no cfssl needed, etc) - its huge

	obtain_latest_version_k8s_worker_containerd
	log info "Downloading k8s-worker-containerd package of version '${latest_release_version_k8s_worker_containerd}'..."

	declare deb_file down_url down_dir full_deb_path
	deb_file="k8s-worker-containerd_amd64_noble.deb"
	down_url="https://github.com/armsurvivors/k8s-worker-containerd/releases/latest/download/${deb_file}"
	down_dir="/cache/extra"
	mkdir -p "${down_dir}"
	full_deb_path="${down_dir}/${latest_release_version_k8s_worker_containerd}_${deb_file}"

	if [[ -f "${full_deb_path}" ]]; then
		log info "Package already downloaded: ${full_deb_path}"
	else
		log info "Will download ${full_deb_path} from latest release..."
		wget --no-cache --no-check-certificate --progress=dot:mega --local-encoding=UTF-8 --output-document="${full_deb_path}.tmp" "${down_url}"
		mv -v "${full_deb_path}.tmp" "${full_deb_path}"
	fi

	# Add the package to the mkosi extra-packages directory, so it can be found by mkosi
	# Do NOT include the version, so it can always be referred to by the same name
	# Those functions run in very different contexts, so we can't just pass the path around.
	cp -v "${full_deb_path}" "extra-packages/${latest_release_version_k8s_worker_containerd}_${deb_file}"
}

function config_mkosi_pre::k8s_worker_containerd_package() {
	obtain_latest_version_k8s_worker_containerd              # again, since this runs in a different shell context
	mkosi_config_add_rootfs_packages "k8s-worker-containerd" # in extra-packages; mkosi builds a temporary repo with the extra-packages in it
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

	# # Show the differences between the new config and the copy
	# log info "Differences in containerd's config.toml after SystemdCgroup configuration..."
	# diff -u /etc/containerd/config.toml.orig /etc/containerd/config.toml > toml.diff || true
	# batcat --paging=never --force-colorization --wrap auto --terminal-width 80 --theme=Dracula --language=diff --file-name "containerd config.toml diff after systemd config" toml.diff
	# cat toml.diff
	# rm -f toml.diff

	echo "Config cri-tools to use containerd..."
	cat <<- EOD > /etc/crictl.yaml
		runtime-endpoint: unix:///var/run/containerd/containerd.sock
	EOD
}

function mkosi_script_postinst_chroot::990_late_validate_containerd_config_and_pretty_print() {
	# Lets make sure the changes produce valid containerd toml, and use containerd itself to reformat it
	log info "Testing containerd config.toml for validity..."
	containerd config dump > /etc/containerd/config.toml.validated
	log info "containerd config.toml valid."
	mv -v /etc/containerd/config.toml.validated /etc/containerd/config.toml
	cp -v /etc/containerd/config.toml /etc/containerd/config.toml.final.validated.mkosi
	#log info "Final validated containerd config.toml:"
	#cat /etc/containerd/config.toml
}
