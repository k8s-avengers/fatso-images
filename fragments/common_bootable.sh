#!/usr/bin/env bash

function config_mkosi_post::350_common_bootable() {
	declare -g -a KERNEL_CMDLINE_FRAGMENTS=()
}

function config_mkosi_post::990_common_bootable_render_kernel_cmdline() {
	mkosi_conf_begin_edit "common bootable stuff"
	mkosi_conf_config_value "Content" "KernelCommandLine" "${KERNEL_CMDLINE_FRAGMENTS[*]}"
	mkosi_conf_finish_edit "common bootable stuff"

}
