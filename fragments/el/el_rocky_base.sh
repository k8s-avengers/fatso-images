#!/usr/bin/env bash

function config_mkosi_pre::rocky_mirror() {
	mkosi_conf_begin_edit "mirror"
	mkosi_conf_config_value "Distribution" "Mirror" "http://rocky-linux-europe-west4.production.gcp.mirrors.ctrliq.cloud/pub" # NO /rocky at the end
	mkosi_conf_finish_edit "mirror"
}
