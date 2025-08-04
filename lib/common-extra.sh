#!/usr/bin/env bash
# common-extra.sh: extra functions for mkosi scripts; not included in the Dockerfile-related scripts.

# Helpers for downloading stuff from GitHub.
function download_one_github_release_file() {
	declare github_release_dl_url github_release_fn
	github_release_dl_url="${1}"
	github_release_fn="${2}"

	log info "Downloading GitHub asset from ${github_release_dl_url} to file /cache/extra/${github_release_fn}"

	# Download, if not already downloaded.
	if [[ -f "/cache/extra/${github_release_fn}" ]]; then
		log info "GitHub asset item already downloaded; /cache/extra/${github_release_fn}"
	else
		log info "Downloading GitHub asset item '${github_release_fn}'..."
		wget --progress=dot:giga --local-encoding=UTF-8 --output-document="/cache/extra/${github_release_fn}.tmp" "${github_release_dl_url}"
		mv "/cache/extra/${github_release_fn}.tmp" "/cache/extra/${github_release_fn}"
		ls -lah "/cache/extra/${github_release_fn}"
	fi

	# Add the package to the mkosi extra-packages directory, so it can be found by mkosi
	cp -v "/cache/extra/${github_release_fn}" "extra-packages/${github_release_fn}"
}

function download_one_github_release_file_meta() {
	declare meta_file="${1}"
	# bomb if unset or empty or all spaces
	if [[ -z "${meta_file}" || "${meta_file}" =~ ^[[:space:]]*$ ]]; then
		log error "Invalid meta file name: '${meta_file}'"
		exit 1
	fi
	shift

	declare meta_name="${1}"
	# bomb if unset or empty or all spaces
	if [[ -z "${meta_name}" || "${meta_name}" =~ ^[[:space:]]*$ ]]; then
		log error "Invalid meta name: '${meta_name}'"
		exit 1
	fi
	shift

	# shellcheck disable=SC1090 # dynamic source
	source "meta.${meta_file}.conf.sh"

	declare dl_url dl_file
	dl_url_var_name="${meta_name}_url"
	dl_url="${!dl_url_var_name}"
	dl_file_var_name="${meta_name}_file"
	dl_file="${!dl_file_var_name}"

	log info download_one_github_release_file "${dl_url}" "${dl_file}"
	download_one_github_release_file "${dl_url}" "${dl_file}"
}

function find_one_github_release_file() {
	declare github_org_repo="${1}"
	# bomb if unset or if does not contain a slash
	if [[ -z "${github_org_repo}" || "${github_org_repo}" != */* ]]; then
		log error "Invalid GitHub org/repo: '${github_org_repo}'"
		exit 1
	fi
	shift
	declare github_tag="${1}"
	# bomb if unset or empty or all spaces
	if [[ -z "${github_tag}" || "${github_tag}" =~ ^[[:space:]]*$ ]]; then
		log error "Invalid GitHub tag: '${github_tag}'"
		exit 1
	fi
	shift
	declare github_release_file_prefix="${1}"
	# bomb if unset or empty or all spaces
	if [[ -z "${github_release_file_prefix}" || "${github_release_file_prefix}" =~ ^[[:space:]]*$ ]]; then
		log error "Invalid GitHub release file prefix: '${github_release_file_prefix}'"
		exit 1
	fi

	declare github_release_api_url="https://api.github.com/repos/${github_org_repo}/releases/${github_tag}"

	declare cache_key_inputs="undetermined" cache_key_sha1="undetermined"
	cache_key_inputs="${github_release_api_url}"
	cache_key_sha1="$(echo -n "${cache_key_inputs}" | sha1sum | cut -d ' ' -f 1)"

	log debug "Cache key for GitHub lookup: '${cache_key_sha1}'"

	declare cache_dir="${CACHE_DIR_REMOTE_LOOKUPS}"
	declare cache_file="${cache_dir}/github_releases_${cache_key_sha1}.json"
	log debug "Cache file for GitHub lookup: '${cache_file}'"

	# if cache file exists, and is not expired, use it
	declare cache_pending=no
	declare cache_miss=yes
	if [[ -f "${cache_file}" ]]; then
		log info "Using CACHED GitHub release file meta: ${cache_file}"
		if [[ "$(find "${cache_file}" -mmin +30)" ]]; then # check if the cache file is older than 30 minutes
			log info "GitHub release file meta cache is older than 30 minutes, will refresh it: ${cache_file}"
		else
			log info "GitHub release file meta cache is fresh, using it: ${cache_file}"
			cache_miss=no
		fi
	fi

	if [[ "${cache_miss}" == "yes" ]]; then
		# produce the cache file by running curl
		log info "GitHub CACHE MISS for release file meta: ${cache_file}"
		curl -sL "${github_release_api_url}" > "${cache_file}.tmp"
		log debug "GitHub release file meta cached: ${cache_file}.tmp"
		cache_pending=yes
	fi

	function find_one_github_release_file_meta_filter_out() {
		cat # no filter
	}
	# if "filter_out" is set, eval a new function with it's body
	if [[ -n "${filter_out}" ]]; then
		eval "function find_one_github_release_file_meta_filter_out() { ${filter_out}; }"
	fi

	function find_one_github_release_file_meta_filter_in() {
		cat # no filter
	}
	# if "filter_in" is set, eval a new function with it's body
	if [[ -n "${filter_in}" ]]; then
		eval "function find_one_github_release_file_meta_filter_in() { ${filter_in}; }"
	fi

	log info "GitHub releases URL: ${github_release_api_url}"

	github_release_dl_url="$(
		curl -sL "${github_release_api_url}" | jq . | grep "browser_download_url" |
			grep "/${github_release_file_prefix}" |
			find_one_github_release_file_meta_filter_out |
			find_one_github_release_file_meta_filter_in |
			cut -d '"' -f 4
	)"
	github_release_fn="${github_release_dl_url##*/}"

	# Check if it's empty, if so, bomb
	if [[ -z "${github_release_fn}" || "${github_release_fn}" =~ ^[[:space:]]*$ ]]; then
		log error "No GitHub release file found for '${github_release_file_prefix}' in '${github_org_repo}' at tag '${github_tag}'"
		log error "Or, maybe the filters are too strict?"
		log error "Or, maybe GitHub rate limit is hit?"
		log error "Or, maybe the result would be on a second page?"
		exit 1
	fi

	# Confirm the cache after checking, if pending
	if [[ "${cache_pending}" == "yes" ]]; then
		mv -v "${cache_file}.tmp" "${cache_file}"
		log info "Cache file confirmed: ${cache_file}"
	fi

	return 0
}

function find_one_github_release_file_meta() {
	declare meta_file="${1}"
	# bomb if unset or empty or all spaces
	if [[ -z "${meta_file}" || "${meta_file}" =~ ^[[:space:]]*$ ]]; then
		log error "Invalid meta file name: '${meta_file}'"
		exit 1
	fi
	shift

	declare meta_name="${1}"
	# bomb if unset or empty or all spaces
	if [[ -z "${meta_name}" || "${meta_name}" =~ ^[[:space:]]*$ ]]; then
		log error "Invalid meta name: '${meta_name}'"
		exit 1
	fi
	shift

	declare github_release_dl_url github_release_fn
	find_one_github_release_file "${@}"

	# lets write those to a file in WORK_DIR so downloader can reach it
	cat <<- META_FILE_FRAGMENT >> "${WORK_DIR}/meta.${meta_file}.conf.sh"
		declare ${meta_name}_file="${github_release_fn}"
		declare ${meta_name}_url="${github_release_dl_url}"
	META_FILE_FRAGMENT

}
