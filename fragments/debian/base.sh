#!/usr/bin/env bash

function config_mkosi_post::110_debian_base_distro() { # Override the stuff in the Ubuntu base
	# Basic stuff for Debian bookworm/stable
	mkosi_conf_begin_edit "base"
	mkosi_conf_config_value "Distribution" "Distribution" "debian"
	mkosi_conf_config_value "Distribution" "Release" "bookworm"
	#mkosi_conf_config_value "Distribution" "Repositories" "main"
	#mkosi_conf_config_value "Distribution" "Mirror" "http://deb.debian.org/debian"
	mkosi_conf_finish_edit "base"
}
