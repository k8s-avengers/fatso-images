# Add this fragment to EL flavours to keep all repos enabled in the final image.
# This is useful for actual mutable images, eg, workstations, etc.
# Both the mkosi-generated repos, and the package-tree repos will be enabled.

# Runs very late in mkosi-post config phase.
function config_mkosi_post::990_copy_package_manage_tree_repos_to_image_itself() {
	log warn "Copying package-manager-tree repos to the image itself..."
	mkdir -p "${WORK_DIR}/mkosi.extra/etc"
	cp -rvp "${WORK_DIR}/package-manager-tree/etc/yum.repos.d" "${WORK_DIR}/mkosi.extra/etc/yum.repos.d-packagetree"
}

# very late in postinst phase
function mkosi_script_postinst_chroot::990_show_repos_at_postinst() {
	log warn "Listing repos at postinst stage..."
	ls -laht /etc/yum.repos.d/ || true
	ls -laht /etc/yum.repos.d-packagetree || true

	# preserve a copy of repos at this stage
	cp -rvp /etc/yum.repos.d /etc/yum.repos.d-postinst-late
}

# very late in finalize stage
function mkosi_script_finalize_chroot::995_show_repos_at_end() {
	log warn "Listing repos at finalize stage..."
	ls -laht /etc/yum.repos.d/ || true
	ls -laht /etc/yum.repos.d-packagetree || true
	ls -laht /etc/yum.repos.d-postinst-late || true

	log info "Consolidating repos (postinst/packagetree/finalize)..."
	mkdir -p /etc/yum.repos.d-image
	cp -v /etc/yum.repos.d-packagetree/* /etc/yum.repos.d-image/ || true
	cp -v /etc/yum.repos.d-postinst-late/* /etc/yum.repos.d-image/ || true
	cp -v /etc/yum.repos.d/* /etc/yum.repos.d-image/ || true

	# replace
	rm -rf /etc/yum.repos.d
	cp -rvp /etc/yum.repos.d-image /etc/yum.repos.d
	ls -laht /etc/yum.repos.d || true
}
