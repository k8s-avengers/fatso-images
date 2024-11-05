#!/usr/bin/env bash

function config_mkosi_pre::rocky_mirror() {
	mkosi_conf_begin_edit "mirror"
	mkosi_conf_config_value "Distribution" "Mirror" "https://rocky-linux-europe-west4.production.gcp.mirrors.ctrliq.cloud/pub/rocky" # /rocky at the end since mkosi 24.0
	mkosi_conf_finish_edit "mirror"
}
