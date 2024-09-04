#!/usr/bin/env bash

# logger utility, output ANSI-colored messages to stderr; first argument is level (debug/info/warn/error), all other arguments are the message.
declare -A log_colors=(["debug"]="0;36" ["info"]="0;32" ["korok"]="1;32" ["warn"]="1;33" ["error"]="1;31")
declare -A log_emoji=(["debug"]="🐛" ["info"]="🌿" ["korok"]="🌱" ["warn"]="🚸" ["error"]="🚨")
function log() {
	declare level="${1}"
	shift
	[[ "${level}" == "debug" && "${DEBUG}" != "yes" ]] && return # Skip debugs unless DEBUG=yes is set in the environment
	declare color="\033[${log_colors[${level}]}m"
	declare emoji="${log_emoji[${level}]}"
	declare ansi_reset="\033[0m"
	level=$(printf "%-5s" "${level}") # pad to 5 characters before printing
	echo -e "${emoji} ${ansi_reset}[${color}${level}${ansi_reset}] ${color}${*}${ansi_reset}" >&2
}

function install_dependencies() {
	declare -a debian_pkgs=()
	declare -a brew_pkgs=()
	declare -a pipx_pkgs=()

	command -v pipx > /dev/null || {
		brew_pkgs+=("pipx")
	}
	command -v jq > /dev/null || {
		debian_pkgs+=("jq")
		brew_pkgs+=("jq")
	}
	command -v crudini > /dev/null || {
		debian_pkgs+=("crudini")
		pipx_pkgs+=("crudini")
	}

	# If more than zero entries in the array, install
	if [[ ${#debian_pkgs[@]} -gt 0 ]]; then
		# If running on Debian or Ubuntu...
		if [[ -f /etc/debian_version ]]; then
			log warn "Installing dependencies: ${debian_pkgs[*]}"
			sudo apt -y update
			sudo apt -y install "${debian_pkgs[@]}"
		elif [[ "$(uname)" == "Darwin" ]]; then
			log info "Skipping Debian deps installation for Darwin..."
		else
			log error "Don't know how to install the equivalent of Debian packages *on the host*: ${debian_pkgs[*]} -- teach me!"
		fi
	else
		log info "All deps found, no apt installs necessary on host."
	fi

	if [[ "$(uname)" == "Darwin" ]]; then
		if [[ ${#debian_pkgs[@]} -gt 0 ]]; then
			log info "Detected Darwin, assuming 'brew' is available: running 'brew install ${brew_pkgs[*]}'"
			brew install "${brew_pkgs[@]}"
		fi
		if [[ ${#pipx_pkgs[@]} -gt 0 ]]; then
			log info "Detected Darwin, assuming 'pipx' is available: running 'pipx install ${pipx_pkgs[*]}'"
			pipx install "${pipx_pkgs[@]}"
		fi
	fi

	return 0 # there's a shortcircuit above
}

function check_docker_daemon_for_sanity() {
	# Shenanigans to go around error control & capture output in the same effort, 'docker info' is slow.
	declare docker_info docker_buildx_version
	docker_info="$({ docker info 2> /dev/null && echo "DOCKER_INFO_OK"; } || true)"

	if [[ ! "${docker_info}" =~ "DOCKER_INFO_OK" ]]; then
		log error "'docker info' failed. Is Docker installed & your user in the correct group?"
		exit 3
	fi

	docker_buildx_version="$(echo "${docker_info}" | grep -i -e "buildx:" || true | cut -d ":" -f 2 | xargs echo -n)"
	log debug "Docker Buildx version" "${docker_buildx_version}"

	if [[ -z "${docker_buildx_version}" ]]; then
		log info "'docker info' indicates there's no buildx installed."
		declare -g -r -i DOCKER_HAS_BUILDX=0
	else
		log info "'docker info' indicates there's buildx installed."
		declare -g -r -i DOCKER_HAS_BUILDX=1
	fi

	# Once we know docker is sane, hook up a function that helps us trace invocations.
	function docker() {
		log debug "--> docker $*"
		command docker "$@"
	}

}

# How sad it is that one needs to write this function in 2024
function is_element_in_array() {
	declare element="$1"
	shift
	declare -a array=("$@")

	if printf '%s\0' "${array[@]}" | grep -qwz "${element}"; then
		log debug "Element '${element}' found in array."
		return 0
	else
		log debug "Element '${element}' NOT found in array."
		return 1
	fi
}

# Also sad
function array_join_elements_by {
	local d=${1-} f=${2-}
	if shift 2; then
		printf %s "$f" "${@/#/$d}"
	fi
}

function batcat() {
	[[ "${BAT}" != "me" ]] && return 0
	command batcat --color=always --paging=never "${@}"
}
