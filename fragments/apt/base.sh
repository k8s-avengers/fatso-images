#!/usr/bin/env bash

# apt/common: common base fragment between Ubuntu and Debian

function config_mkosi_pre::000_apt_base() {
	declare -a pkgs=(
		# a mess of other stuff, split later into better named fragments
		"sudo" # for, well, sudo'ing

		"sysstat"         # for iostat et al
		"psmisc"          # for killall etc
		"bash"            # our favorite shell
		"bash-completion" # for tab completion
		"htop"            # for serious top
		"btop"            # for fun top
		"zsh"             # for people who prefer it over bash
		"screen"          # for people who don't like tmux
		"tmux"            # for people who don't like screen
		"jq"              # swiss-army JSON tool

		"vim"  # for those who like it
		"nano" # for those who don't

		"less"                 # for
		"apt-utils"            # for
		"ca-certificates"      # for
		"console-setup"        # for
		"iproute2"             # for
		"lvm2"                 # for
		"nfs-common"           # for
		"dialog"               # for
		"whiptail"             # for
		"locales"              # for
		"inetutils-ping"       # for
		"inetutils-traceroute" # for
		"iptables"             # for

		"openssh-client"

		"curl" # for
		"wget" # for

		#"git"               # for developers (move to workstation fragment)
		"file"              # for magic file type detection
		"tree"              # for listing directories
		"zstd"              # for zstd-compressed grub initrds
		"jq"                # for JSON swiss army knife
		"pv"                # for pipe viewer
		"bc"                # for basic calculator
		"hdparm"            # hdparm: for disk performance tuning
		"neofetch"          # for lols
		"bat"               # for cat with wings
		"dnsutils"          # for nslookup et al
		"colorized-logs"    # for pipetty et al
		"command-not-found" # for when you forget which package brings a given executable

		"udisks2"          # for
		"upower"           # for
		"systemd-resolved" # for networkd-driven name resolution (mkosi already juggles the symlink during image build)
		"systemd-sysv"     # for compat

		"picocom" # for those who think minicom is too big
	)
	mkosi_config_add_rootfs_packages "${pkgs[@]}"
}

function config_mkosi_post::990_ubuntu_base_render_pkgs() {
	declare rootfs_packages_joined_by_comma="" # add the MKOSI_ROOTFS_PACKAGES array to the mkosi.conf
	rootfs_packages_joined_by_comma="$(array_join_elements_by "," "${MKOSI_ROOTFS_PACKAGES[@]}")"

	mkosi_conf_begin_edit "packages"
	mkosi_conf_config_value "Content" "Packages" "${rootfs_packages_joined_by_comma}"
	mkosi_conf_finish_edit "packages"
}

function config_mkosi_post::apt_base_setup_grow_rootfs_at_runtime() {
	log info "Setting up runtime systemd-repart to grow the rootfs to the full size of the disk."
	mkosi_stdin_to_work_file "mkosi.extra/usr/lib/repart.d" "10-root.conf" <<- ROOTFS_REPART_GROW_FULL
		[Partition]
		Type=root
	ROOTFS_REPART_GROW_FULL
}

function mkosi_script_postinst_chroot::010_ubuntu_early_fixes() {
	export DEBIAN_FRONTEND=noninteractive
	export HOME="/root" # No HOME is set otherwise, fix it

	# locale fix
	sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
	locale-gen

	declare ROOT_PARTLABEL="undefined"
	case "${OS_ARCH}" in
		"amd64")
			ROOT_PARTLABEL="root-x86-64"
			;;
		"arm64")
			ROOT_PARTLABEL="root-arm64"
			;;
		*)
			log error "Unsupported architecture '${OS_ARCH}' for systemd-standard root partition label."
			exit 1
			;;
	esac
	log info "rootfs partition label: ${OS_ARCH}, TOOLCHAIN_ARCH: ${TOOLCHAIN_ARCH}, ROOT_PARTLABEL: ${ROOT_PARTLABEL}"

	# Let's setup an /etc/fstab so things are mounted and rootfs is grown
	cat <<- EOD > /etc/fstab
		# rootfs by partition label, tell it to grow and not waste (a)time
		PARTLABEL="${ROOT_PARTLABEL}" / ext4 defaults,noatime,x-systemd.growfs 0 1
		# attention: the way systemd wants it, in /boot; I'd rather have it in /boot/efi cos I'm ancient
		PARTLABEL="esp" /boot vfat defaults 0 2 
	EOD
}

function mkosi_script_postinst_chroot::160_ubuntu_early_apt_get_update() {
	# update package lists so apt is ready-to-go when image deployed
	apt-get -o "DPkg::Use-Pty=false" -y update --error-on=any
}

function mkosi_script_postinst_chroot::980_ubuntu_late_fixes() {
	log info "Late fixes for Ubuntu..."
	# Remove Canonical's ads # @TODO insert our own image ID and such
	rm -fv /etc/update-motd.d/10-help-text /etc/update-motd.d/50-motd-news

	log info "Late apt update / apt upgrade to guarantee package up-to-dateness even if mkosi incremental cache used..."
	apt-get -o "DPkg::Use-Pty=false" -y update
	apt-get -o "DPkg::Use-Pty=false" -y full-upgrade

	# Clean apt cache (debs)
	apt -o "DPkg::Use-Pty=false" -y clean
}

function mkosi_script_finalize_chroot::980_ubuntu_late_fixes() {
	log info "Largest 20 folders, at finalize stage..."
	du -h -d 7 -x / | sort -h | tail -n 20

	log info "Largest 20 package installed sizes, at finalize stage..."
	dpkg-query -Wf '${Installed-Size}\t${Package}\n' | sort -n | tail -n 20
}

# NOT an implementation, just regular function; used by other fragments!
function mkosi_config_add_rootfs_packages() {
	declare -g -a MKOSI_ROOTFS_PACKAGES          # outer scope
	declare -g -A MKOSI_ROOTFS_PACKAGES_ADDED_BY # outer scope
	declare pkgs=("$@")
	declare pkg
	for pkg in "${pkgs[@]}"; do
		log debug "Adding package to rootfs: ${pkg}"
		if ! is_element_in_array "${pkg}" "${MKOSI_ROOTFS_PACKAGES[@]}"; then
			log debug "[${CURRENT_IMPLEMENTATION}] Adding new package to rootfs: ${pkg}"
			MKOSI_ROOTFS_PACKAGES+=("${pkg}")
			MKOSI_ROOTFS_PACKAGES_ADDED_BY["${pkg}"]="${CURRENT_IMPLEMENTATION}"
		else
			log warn "[${CURRENT_IMPLEMENTATION}] Package already in rootfs: ${pkg} (added by '${MKOSI_ROOTFS_PACKAGES_ADDED_BY["${pkg}"]}')"
		fi
	done
}

function config_mkosi_pre::disable_audit() {
	log info "Disabling audit in kernel command line..."
	declare -g -a KERNEL_CMDLINE_FRAGMENTS
	KERNEL_CMDLINE_FRAGMENTS+=("audit=0") # we don't have nor want auditd. stop spewing audit logs to dmesg
}
