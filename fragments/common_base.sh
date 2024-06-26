#!/usr/bin/env bash

function config_mkosi_post::300_common_base() {
	mkdir -pv "${WORK_DIR}/package-manager-tree"
	mkdir -pv "${WORK_DIR}/extra-packages"

	mkosi_conf_begin_edit "common base stuff"
	mkosi_conf_config_value "Output" "ManifestFormat" "json"
	mkosi_conf_config_value "Content" "Locale" "en_US.UTF-8"
	mkosi_conf_config_value "Content" "LocaleMessages" "en_US.UTF-8"
	mkosi_conf_config_value "Content" "Timezone" "Europe/Amsterdam"
	mkosi_conf_config_value "Content" "Hostname" "${FLAVOR}"
	mkosi_conf_config_value "Content" "WithNetwork" "yes"
	mkosi_conf_config_value "Content" "RootPassword" "rootrootroot"
	mkosi_conf_config_value "Content" "Autologin" "true"

	mkosi_conf_config_value "Distribution" "PackageManagerTrees" "package-manager-tree"
	mkosi_conf_config_value "Content" "BuildSources" "./extra-packages:extra-packages"

	mkosi_conf_finish_edit "common base stuff"
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
