#!/usr/bin/env bash

function config_mkosi_init::350_common_base() {
	declare -g -A MKOSI_CONTENT_ENVIRONMENT=(
		["FLAVOR"]="${FLAVOR}"
		["IMAGE_VERSION"]="${IMAGE_VERSION}"
		["IMAGE_FLAVOR_VERSION_ID"]="${FLAVOR}-v${IMAGE_VERSION}" # Override this for predictable filenames for CI pipelines
	)
}

function config_mkosi_post::300_common_base() {
	mkdir -pv "${WORK_DIR}/package-manager-tree"
	mkdir -pv "${WORK_DIR}/extra-packages"

	mkosi_conf_begin_edit "common base stuff"
	mkosi_conf_config_value "Output" "ManifestFormat" "json" # processed below in mkosi_script_post_mkosi_host::output_manifest
	mkosi_conf_config_value "Content" "Locale" "en_US.UTF-8"
	mkosi_conf_config_value "Content" "LocaleMessages" "en_US.UTF-8"
	mkosi_conf_config_value "Content" "Timezone" "Europe/Amsterdam"
	mkosi_conf_config_value "Content" "Hostname" "${FLAVOR}"
	mkosi_conf_config_value "Content" "WithNetwork" "yes"
	mkosi_conf_config_value "Content" "RootPassword" "rootrootroot"
	mkosi_conf_config_value "Content" "Autologin" "true"

	mkosi_conf_config_value "Distribution" "PackageManagerTrees" "package-manager-tree"
	mkosi_conf_config_value "Content" "PackageDirectories" "./extra-packages" # This replaces the mkosi 23.x "BuildSources" directive

	mkosi_conf_finish_edit "common base stuff"
}

function config_mkosi_post::990_common_base_render_environment_dict() {
	log info "Rendering environment dict; number of envs: ${#MKOSI_CONTENT_ENVIRONMENT[@]}"

	declare env_file="${WORK_DIR}/mkosi.env" # used by mkosi
	echo -n "" > "${env_file}"

	declare env_file_exports="${WORK_DIR}/mkosi.env.exports.sh" # sourced into env inside docker host for host-side scripts
	echo -n "" > "${env_file_exports}"

	for key in "${!MKOSI_CONTENT_ENVIRONMENT[@]}"; do
		echo "${key}=${MKOSI_CONTENT_ENVIRONMENT[$key]}" >> "${env_file}"
		echo "export ${key}=\"${MKOSI_CONTENT_ENVIRONMENT[$key]}\"" >> "${env_file_exports}" # @TODO won't encode quotes
	done

	mkosi_conf_begin_edit "common_base env stuff"
	mkosi_conf_config_value "Content" "EnvironmentFiles" "mkosi.env" # Be explicit; mkosi.env would be picked up automatically
	mkosi_conf_finish_edit "common_base env stuff"
}

function mkosi_script_postinst_chroot::000_common_base_early_debug() {
	log info "Some debug info, early in the chroot; resolv.conf"
	ls -la /etc/resolv.conf || true
	cat /etc/resolv.conf || true

	log info "Some debug info, early in the chroot; PATH/HOME and http_proxy/no_proxy"
	echo "PATH: $PATH" || true
	echo "HOME: $HOME" || true
	echo "http_proxy: ${http_proxy:-"<none>"}" || true
	echo "https_proxy: ${https_proxy:-"<none>"}" || true
	echo "no_proxy: ${no_proxy:-"<none>"}" || true
}

# Heh, this would be better handled by output_xxxx themselves, so the manifest can match the actual dist filename
function mkosi_script_post_mkosi_host::output_manifest() {
	: "${IMAGE_FLAVOR_VERSION_ID:?IMAGE_FLAVOR_VERSION_ID is not set, cannot continue.}" # set by common_base

	declare mkosi_produced_manifest="/out/image.manifest"
	log info "mkosi-output manifest JSON ${mkosi_produced_manifest}"

	declare final_dist_manifest="/dist/${IMAGE_FLAVOR_VERSION_ID}.manifest.json"
	log warn "Final manifest JSON file: ${final_dist_manifest}"

	# copy the manifest file to the dist dir
	cp "${mkosi_produced_manifest}" "${final_dist_manifest}"
}
