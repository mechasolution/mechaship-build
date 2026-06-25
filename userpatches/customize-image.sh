#!/bin/bash

set -eEuo pipefail

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP $ARCH
RELEASE="${1:-}"
LINUXFAMILY="${2:-}"
BOARD="${3:-}"
BUILD_DESKTOP="${4:-}"
ARCH="${5:-}"

: "${MECHASHIP_VARIANT:=v26.01b}"

export RELEASE LINUXFAMILY BOARD BUILD_DESKTOP ARCH MECHASHIP_VARIANT

mechaship_green() {
	if [[ "${ANSI_COLOR:-}" == "none" ]]; then
		printf '%s' "$*"
	else
		printf '\033[1;32m%s\033[0m' "$*"
	fi
}

Main() {
	case "${RELEASE}" in
		noble)
			run_mechaship_customizations
			;;
		*)
			echo "No MechaShip customization for RELEASE=${RELEASE}"
			;;
	esac
}

run_mechaship_customizations() {
	local script
	local scripts_dir="/tmp/overlay/mechaship/scripts"
	local index=0
	local total=0

	if [[ ! -d "${scripts_dir}" ]]; then
		echo "MechaShip scripts directory is missing: ${scripts_dir}" >&2
		return 1
	fi

	for script in "${scripts_dir}"/[0-9][0-9]-*.sh; do
		[[ -f "${script}" ]] || continue
		total=$((total + 1))
	done

	for script in "${scripts_dir}"/[0-9][0-9]-*.sh; do
		[[ -f "${script}" ]] || continue
		index=$((index + 1))
		run_mechaship_script "${script}" "${index}" "${total}"
	done
}

run_mechaship_script() {
	local script="$1"
	local index="$2"
	local total="$3"
	local name
	local start
	local end
	local rc

	name="$(basename "${script}")"
	start="$(date +%s)"

	echo
	echo "================================================================"
	echo "$(mechaship_green " MechaShip customization ${index}/${total}: ${name}")"
	echo "$(mechaship_green " Started: $(date -u '+%Y-%m-%d %H:%M:%S UTC')")"
	echo "================================================================"

	set +e
	bash "${script}"
	rc=$?
	set -e

	end="$(date +%s)"

	if [[ "${rc}" -eq 0 ]]; then
		echo "----------------------------------------------------------------"
		echo "$(mechaship_green " Completed: ${name} ($((end - start))s)")"
		echo "----------------------------------------------------------------"
	else
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
		echo " Failed: ${name} rc=${rc} ($((end - start))s)" >&2
		echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
		return "${rc}"
	fi
}

Main "$@"
