#!/usr/bin/env bash

# aha, you expected a k3s deployment here, but I be extra lazy, just add scripts to deploy k3s.
function config_mkosi_post::k3s_scripts() {
	mkosi_asset_to_work_mkosi_extra "k3s/k3s_cilium.sh" "usr/local/sbin" "k3s_cilium.sh" "+x"
	mkosi_asset_to_work_mkosi_extra "k3s/k3s_join.sh" "usr/local/sbin" "k3s_join.sh" "+x"
}
