#!/usr/bin/env bash

# Great, some more "metaprogramming" in bash. Reflection if you will.

function process_inventories() {
	# Obtain, using compgen, the list of functions that start with "flavor_base_"
	declare -a base_flavor_functions=()
	# shellcheck disable=SC2207 # Split it, man.
	base_flavor_functions+=($(compgen -A function | grep "^flavor_base_" | sed -e 's/^flavor_base_//g' || true))
	log debug "Found ${#base_flavor_functions[@]} base flavor functions: ${base_flavor_functions[*]}"

	# Same, but for flavor_target_ functions
	declare -a target_flavor_functions=()
	# shellcheck disable=SC2207 # Split
	target_flavor_functions+=($(compgen -A function | grep "^flavor_target_" | sed -e 's/^flavor_target_//g' || true))
	log debug "Found ${#target_flavor_functions[@]} target flavor functions: ${target_flavor_functions[*]}"

	# Same, but for flavor_vendor_ functions
	declare -a vendor_flavor_functions=()
	# shellcheck disable=SC2207 # Split
	vendor_flavor_functions+=($(compgen -A function | grep "^flavor_vendor_" | sed -e 's/^flavor_vendor_//g' || true))
	log debug "Found ${#vendor_flavor_functions[@]} vendor flavor functions: ${vendor_flavor_functions[*]}"
	
	# Combinatorics time! 🤓
	for vendor_flavor in "${vendor_flavor_functions[@]}"; do
		for base_flavor in "${base_flavor_functions[@]}"; do
			for target_flavor in "${target_flavor_functions[@]}"; do
				# Small detour, if target_vendor == 'standard', pretend it's not there; it's the default, thus short-circuit it out
				if [[ "${vendor_flavor}" == "standard" ]]; then
					declare one_final_flavor="${base_flavor}-${target_flavor}"
					all_final_flavors+=("${one_final_flavor}")
					flavor_invocations["${one_final_flavor}"]="BASE_FLAVOR='${base_flavor}' TARGET_FLAVOR='${target_flavor}' VENDOR_FLAVOR=''"
					continue
				fi

				declare one_final_flavor="${vendor_flavor}-${base_flavor}-${target_flavor}"
				all_final_flavors+=("${one_final_flavor}")
				flavor_invocations["${one_final_flavor}"]="BASE_FLAVOR='${base_flavor}' TARGET_FLAVOR='${target_flavor}' VENDOR_FLAVOR='${vendor_flavor}'"
			done
		done
	done

	# Sort array, wtf crap bash
	declare all_flavors_to_sort=""
	for final_flavor in "${all_final_flavors[@]}"; do
		all_flavors_to_sort+="${final_flavor}"$'\n'
	done
	declare -a sorted_flavors=()
	# shellcheck disable=SC2207 # Split
	sorted_flavors+=($(LC_ALL=C sort <<< "${all_flavors_to_sort}"))
	all_final_flavors=("${sorted_flavors[@]}")

	log debug "Found ${#all_final_flavors[@]} final flavors: ${all_final_flavors[*]}"

}
