#!/usr/bin/env bash

# logger utility, output ANSI-colored messages to stderr; first argument is level (debug/info/warn/error), all other arguments are the message.
declare -A log_colors=(["debug"]="0;36" ["info"]="0;32" ["warn"]="0;33" ["error"]="0;31")
declare -A log_emoji=(["debug"]="🐛" ["info"]="📗" ["warn"]="🚧" ["error"]="🚨")
function log() {
	declare level="${1}"
	shift
	declare color="${log_colors[${level}]}"
	declare emoji="${log_emoji[${level}]}"
	echo -e "${emoji} \033[${color}m${SECONDS}: [${level}] $*\033[0m" >&2
}


function install_dependencies() {
	declare -a debian_pkgs=()
	[[ ! -f /usr/bin/jq ]] && debian_pkgs+=("jq")

	# If running on Debian or Ubuntu...
	if [[ -f /etc/debian_version ]]; then
		# If more than zero entries in the array, install
		if [[ ${#debian_pkgs[@]} -gt 0 ]]; then
			log warn "Installing dependencies: ${debian_pkgs[*]}"
			sudo apt -y update
			sudo apt -y install "${debian_pkgs[@]}"
		fi
	else
		log error "Don't know how to install the equivalent of Debian packages: ${debian_pkgs[*]} -- teach me!"
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
		log error "'docker info' indicates there's no buildx installed. Please install docker buildx."
		exit 4
	fi

	# Once we know docker is sane, hook up a function that helps us trace invocations.
	function docker() {
		log debug "--> docker $*"
		command docker "$@"
	}

}
