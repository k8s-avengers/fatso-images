#!/usr/bin/env bash

# nvidia drivers install is done in postinst due to some pkg missing a Pre-Depends somewhere I don't wanna find out
# mkosi-install does magic to use the cache correctly already
function mkosi_script_postinst_host::nvidia_installs() {
	# use prebuilt stuff from ubuntu, which are only linked using the local system (and depend on binutils et al)
	mkosi-install "linux-modules-nvidia-535-server-generic" "nvidia-utils-535-server" "cuda-drivers-fabricmanager-535" "nvtop"
}

function mkosi_script_postinst_chroot::nvidia_fixes() {
	# Black list nouveau module, so nvidia can load.
	cat <<- EOF > /etc/modprobe.d/blacklist-nouveau.conf
		blacklist nouveau
		options nouveau modeset=0
	EOF

	# Actually, obliterate the nouveau module away so mkosi doesn't pick it up for its initrd either
	find /usr/lib -type f -name '*nouveau*' -delete

	return 0
}
