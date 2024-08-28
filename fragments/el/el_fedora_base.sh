#!/usr/bin/env bash

function config_mkosi_pre::fedora_mirror() {
	mkosi_conf_begin_edit "mirror"
	#mkosi_conf_config_value "Distribution" "Mirror" "https://eu.edge.kernel.org/"
	mkosi_conf_finish_edit "mirror"
}
