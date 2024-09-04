function mkosi_script_postinst_chroot::100_setup_docker_registry_mirrors() {
	log info "Setting up Docker registry mirrors with Harbor..."
	docker_registry_prefixes+=(["quay.io"]="harbor.vmtest.pardini.net/quay.io")
	docker_registry_prefixes+=(["docker.io"]="harbor.vmtest.pardini.net/docker.io")
}

function config_mkosi_init::predictable_image_names_sans_version() {
	log warn "Using predictable dist image names rpardini"
	MKOSI_CONTENT_ENVIRONMENT["IMAGE_FLAVOR_VERSION_ID"]="${FLAVOR}-rpardini-predictable"
}