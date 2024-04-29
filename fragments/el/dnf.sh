#!/usr/bin/env bash

# Basic stuff for el_dnf
function config_mkosi_post::100_el_dnf_base_distro() {
	# Bomb if EL_DISTRO is not set; oneliner
	[[ -z "${EL_DISTRO}" ]] && log error "EL_DISTRO is not set by the flavor!" && return 1
	[[ -z "${EL_RELEASE}" ]] && log error "EL_RELEASE is not set by the flavor!" && return 1
	[[ -z "${EL_REPOSITORIES}" ]] && log warning "EL_REPOSITORIES is not set by the flavor!"

	mkosi_conf_begin_edit "base"
	mkosi_conf_config_value "Distribution" "Distribution" "${EL_DISTRO}"
	mkosi_conf_config_value "Distribution" "Release" "${EL_RELEASE}"
	mkosi_conf_config_value "Distribution" "Repositories" "${EL_REPOSITORIES}"
	mkosi_conf_finish_edit "base"
}

function config_mkosi_post::990_el_dnf_base_render_pkgs() {
	declare rootfs_packages_joined_by_comma="" # add the MKOSI_ROOTFS_PACKAGES array to the mkosi.conf
	rootfs_packages_joined_by_comma="$(array_join_elements_by "," "${MKOSI_ROOTFS_PACKAGES[@]}")"

	mkosi_conf_begin_edit "packages"
	mkosi_conf_config_value "Content" "Packages" "${rootfs_packages_joined_by_comma}"
	mkosi_conf_finish_edit "packages"
}

function mkosi_script_postinst_chroot::010_el_dnf_early_fixes() {
	export HOME="/root" # No HOME is set otherwise, fix it

	# Config systemd repart to manage the rootfs on first boot
	mkdir -p /usr/lib/repart.d
	cat <<- EOD > /usr/lib/repart.d/10-root.conf
		[Partition]
		Type=root
	EOD

	# Let's setup an /etc/fstab so things are mounted and rootfs is grown
	cat <<- EOD > /etc/fstab
		# rootfs by partition label, tell it to grow and not waste (a)time
		PARTLABEL="root-x86-64" / ext4 defaults,noatime,x-systemd.growfs 0 1
		# attention: the way systemd wants it, in /boot; I'd rather have it in /boot/efi cos I'm ancient
		PARTLABEL="esp" /boot vfat defaults 0 2 
	EOD
}

function mkosi_script_postinst_chroot::980_el_dnf_late_fixes() {
	# Clean dnf cache (rpms)
	dnf clean all || true
}

function mkosi_script_finalize_chroot::980_el_dnf_late_fixes() {
	log info "Largest folders, at finalize stage..."
	du -h -d 7 -x / | sort -h | tail -n 50

	#log info "dnf package installed sizes, at finalize stage..."
	#dnf repoquery --queryformat "%{SIZE}\t%{NAME}" --all --installed --quiet | sort -n || true
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

# No neofetch in EL, use screenfetch @TODO move out of here
function mkosi_script_postinst_chroot::neofetch() {
	wget --no-check-certificate -O /usr/bin/neofetch "https://raw.githubusercontent.com/KittyKatt/screenFetch/master/screenfetch-dev" || true
	chmod +x /usr/bin/neofetch || true
	ls -la /usr/bin/neofetch || true
}
