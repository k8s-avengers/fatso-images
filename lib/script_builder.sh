#!/usr/bin/env bash

function build_mkosi_script_from_fragments() {
	declare interface="$1"
	declare script_filename="$2"
	create_mkosi_script_from_fragments_specific "${interface}_host" "${WORK_DIR}/${script_filename}"
	create_mkosi_script_from_fragments_specific "${interface}_chroot" "${WORK_DIR}/${script_filename}.chroot"
}

function create_mkosi_script_from_fragments_specific() {
	declare interface="mkosi_script_${1}"
	declare script_filename="${2}"
	declare full_fn="${2}"

	# obtain all matching implementations for the interface
	declare -a fragment_implementations=()
	find_fragment_functions "${interface}"

	# if fragment_implementation arry is empty, we're done; frament_implementations is further use down below
	# allow for empty ones if always="yes" is set
	if [[ "${always:-"no"}" == "no" ]]; then
		if [[ ${#fragment_implementations[@]} -eq 0 ]]; then
			log info "No implementations found for interface '${interface}'"
			return 0
		fi
	fi

	# bash header with the contents of lib/common.sh for logging goodness
	cat <<- EOD > "${full_fn}"
		#!/usr/bin/env bash
		set -e
		# <common.sh>
		$(cat "lib/common.sh")
		# </common.sh>
		log info "fatso: starting '${script_filename}' (all ${#fragment_implementations[@]} '${interface}' methods)..."
	EOD

	if [[ "${DEBUG}" == "yes" ]]; then
		cat <<- EOD >> "${full_fn}"
			log info "fatso: DEBUG ENV '${script_filename}' (all ${#fragment_implementations[@]} '${interface}' methods)..."
			env | sort
		EOD
	fi

	# include the source of all enabled fragments; frag_var defaults to FLAVOR_FRAGMENTS, but can be overriden
	declare one_frag_file
	declare frag_var="${frag_var:-"FLAVOR_FRAGMENTS"}"
	log debug "fragment variable: ${frag_var}"
	declare -a handled_fragments=()
	eval "handled_fragments+=(\"\${${frag_var}[@]}\")" # ewww

	for one_frag_file in "${handled_fragments[@]}"; do
		log info "Enabling fragment: ${one_frag_file} (from ${frag_var})"
		cat <<- EOD >> "${full_fn}"
			log debug "fatso: starting '${script_filename}'; including fragment '${one_frag_file}'..."
			$(cat "fragments/${one_frag_file}.sh")
		EOD
	done

	declare one_impl
	declare -i counter=0
	for one_impl in "${fragment_implementations[@]}"; do
		counter=$((counter + 1))
		log debug "including call to implementation '${one_impl}' for interface '${interface}' into '${script_filename}'..."
		cat <<- EOD >> "${full_fn}"
			log info "fatso: calling '${interface}::${one_impl}' as part of '${script_filename}' (${counter}/${#fragment_implementations[@]} )..."
			${interface}::${one_impl} "\${@}"
		EOD
	done

	# bash footer; won't run if functions fail or exit etc
	cat <<- EOD >> "${full_fn}"
		log info "fatso: finished '${script_filename}' (all ${#fragment_implementations[@]} '${interface}' methods)..."
	EOD

	chmod +x "${full_fn}"
	batcat "${full_fn}"
}
