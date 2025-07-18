#!/usr/bin/env bash

function config_mkosi_pre::el_containerd_pkgs() {
	log info "Finding latest version of el-containerd for EL_RELEASE=${EL_RELEASE} and TOOLCHAIN_ARCH=${TOOLCHAIN_ARCH}..."

	filter_in="grep -e '\.rpm' | grep 'el${EL_RELEASE}' | grep '${TOOLCHAIN_ARCH}' | sed -e 's|%2B|+|'" \
		find_one_github_release_file_meta "containerd" "containerd" "k8s-avengers/el-containerd" "latest" "el-containerd"

	cat "${WORK_DIR}/meta.containerd.conf.sh"

	log info "Adding el-containerd packages to package list..."
	mkosi_config_add_rootfs_packages "el-containerd" # simple name of the package; mkosi builds a temporary repo with the extra-packages in it
}

# This runs outside of mkosi, but inside the Docker container.
function mkosi_script_pre_mkosi_host::el_containerd_download() {
	log info "Downloading el-containerd package..."

	download_one_github_release_file_meta "containerd" "containerd"
}

function mkosi_script_postinst_chroot::400_k8s_el_containerd_install() {
	log warn "Containerd VERSION!"
	# Check by running it under chroot
	containerd --version

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

function mkosi_script_postinst_chroot::990_late_validate_el-containerd_config_and_pretty_print() {
	# Lets make sure the changes produce valid containerd toml, and use containerd itself to reformat it
	log info "Testing containerd config.toml for validity..."
	containerd config dump > /etc/containerd/config.toml.validated
	log info "containerd config.toml valid."
	mv -v /etc/containerd/config.toml.validated /etc/containerd/config.toml
	cp -v /etc/containerd/config.toml /etc/containerd/config.toml.final.validated.mkosi
	#log info "Final validated containerd config.toml:"
	#cat /etc/containerd/config.toml
}

function mkosi_script_finalize_chroot::el_containerd_enable() {
	log info "Enabling containerd service..."
	systemctl enable containerd.service
}
