#!/usr/bin/env bash

function enable_fragments() {
	declare fragment
	for fragment in "${@}"; do
		log info "Enabling fragment: ${fragment}"
		# sugar: allow for fragments to be enabled without the .sh extension
		if [[ ! -f "fragments/${fragment}" ]]; then
			fragment="${fragment}.sh"
		fi
		# check file actually exists before sourcing
		if [[ ! -f "fragments/${fragment}" ]]; then
			log error "Can't find fragment '${fragment}'"
			exit 3
		fi
		# shellcheck disable=SC1090
		source "fragments/${fragment}"
	done
}

function find_fragment_functions() {
	declare interface="$1"
	log debug "Finding fragment functions for interface '${interface}'..."

	declare -a matching_raw_functions=()
	declare intf_marker="${interface}::"
	# shellcheck disable=SC2207 # Split it, man.
	matching_raw_functions+=($(compgen -A function | grep "^${intf_marker}" || true)) # compgen enables bash "metaprogramming" lol
	log info "Found ${#matching_raw_functions[@]} functions for interface '${interface}': ${matching_raw_functions[*]}"
	declare -a implementations=()
	declare one_impl
	for one_impl in "${matching_raw_functions[@]}"; do
		implementations+=("${one_impl#${intf_marker}}")
	done
	log info "Found ${#implementations[@]} implementations for interface '${interface}': ${implementations[*]}"

	# bash really does not lend itself to this. bear with me
	declare -A impl_to_order_map=() order_to_impl_map=()
	for one_impl in "${implementations[@]}"; do
		declare normal_impl
		normal_impl="${one_impl}"
		# if it does not start with a digit, prepend "500_"
		if [[ ! "${normal_impl}" =~ ^[0-9] ]]; then
			log debug "Prepending '500_' to '${normal_impl}'..."
			normal_impl="500_${normal_impl}"
		fi
		impl_to_order_map["${one_impl}"]="${normal_impl}"
		order_to_impl_map["${normal_impl}"]="${one_impl}"
	done

	# set implementations to the keys of order_to_impl_map
	keys_to_sort=("${!order_to_impl_map[@]}")
	log debug "Implementations after normalization: ${implementations[*]}"

	# sort implementations
	declare -a sorted_keys=()
	declare _old_ifs="${IFS}" # ewww
	# shellcheck disable=SC2207 # lol
	IFS=$'\n' sorted_keys=($(LC_ALL=C sort <<< "${keys_to_sort[*]}")) # 🤮
	IFS="${_old_ifs}"                                                 # ewww
	log debug "Implementations after sorting: ${sorted_keys[*]}"

	# lookup back in the map for the original name
	declare -a sorted_impls=()
	for one_impl in "${sorted_keys[@]}"; do
		sorted_impls+=("${order_to_impl_map["${one_impl}"]}")
	done

	declare -i counter=1
	for one_impl in "${sorted_impls[@]}"; do
		log debug "Implementation ${counter} for '${interface}': ${one_impl}"
		((counter++))
	done

	fragment_implementations=("${sorted_impls[@]}") # outer scope, hopefully

}

function run_fragment_implementations() {
	declare interface="$1"
	shift # rest of the arguments will be passed to the implementations
	log debug "Running fragment implementations for interface '${interface}'..."
	declare -a fragment_implementations=()
	find_fragment_functions "${interface}"
	declare one_impl
	for one_impl in "${fragment_implementations[@]}"; do
		log info "Running implementation '${one_impl}' for interface '${interface}'..."
		CURRENT_INTERFACE="${interface}" CURRENT_IMPLEMENTATION="${one_impl}" "${interface}::${one_impl}" "$@"
	done
	log info "All implementations for interface '${interface}' ran."
}

function fragment_function_names_sanity_check() {
	# find functions that have "::" in their name; count them
	# count the unique functions
	# if !=, then we have a problem (copy/paste much?)
	declare -i total_functions=0 unique_functions=0
	total_functions=$(find fragments lib builders flavors -name '*.sh' -print0 | xargs -0 grep --no-filename "function" | grep "::" | sort | wc -l)
	unique_functions=$(find fragments lib builders flavors -name '*.sh' -print0 | xargs -0 grep --no-filename "function" | grep "::" | sort | uniq | wc -l)
	# Ensure both are higher than one
	if [[ ${total_functions} -lt 1 ]]; then
		log error "Found ${total_functions} functions with '::' in their name. This is a problem."
		exit 1
	fi
	if [[ ${total_functions} -ne ${unique_functions} ]]; then
		log error "Found ${total_functions} functions with '::' in their name, but only ${unique_functions} unique ones. This is a problem."
		exit 1
	fi
	log info "Found ${total_functions} functions with '::' in their name, all unique."
}
