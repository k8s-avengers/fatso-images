#!/usr/bin/env bash

function mkosi_conf_config_value() {
	# use crudini to manipulate mkosi.conf in the working directory

	declare section="$1"
	shift
	declare param="$1"
	shift
	crudini --set "${WORK_DIR}/mkosi.conf" "${section}" "${param}" "${@}" # --ini-options=nospace  requires newer crudini
	return 0
}

function mkosi_stdin_to_work_file() {
	declare directories="$1"
	declare filename="$2"
	declare full_dir="${WORK_DIR}/${directories}"
	declare full_file="${full_dir}/${filename}"
	mkdir -p "${full_dir}"
	cat - > "${full_file}"
	log info "Wrote to ${full_file}"
	batcat "${full_file}"
}

function mkosi_asset_to_work_mkosi_extra() {
	declare asset="${1}"
	shift
	declare directories="${1}"
	shift
	declare filename="${1}"
	shift

	declare full_dir="${WORK_DIR}/mkosi.extra/${directories}"
	mkdir -p "${full_dir}"
	declare full_file="${full_dir}/${filename}"

	cp -v "assets/${asset}" "${full_file}"
	# if extra arguments are given, chmod the file
	if [[ "${#}" -gt 0 ]]; then
		chmod -v "${@}" "${full_file}"
	fi

	batcat "${full_file}"
}

function mkosi_conf_begin_edit() {
	declare what="$1"
	log debug "Begin editing mkosi.conf: ${what}"
}

function mkosi_conf_finish_edit() {
	declare what="$1"
	log debug "Finish editing mkosi.conf: ${what}"
	batcat --language=ini "${WORK_DIR}/mkosi.conf"
}
