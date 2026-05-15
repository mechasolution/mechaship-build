#!/bin/bash

set -eEuo pipefail

export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

: "${MECHASHIP_USER:=ubuntu}"
: "${MECHASHIP_PASSWORD:=ubuntu}"
: "${MECHASHIP_REALNAME:=Ubuntu}"
: "${MECHASHIP_EXPIRE_PASSWORD:=yes}"
: "${MECHASHIP_HOSTNAME_PREFIX:=mechaship-}"
: "${MECHASHIP_OVERLAY:=/tmp/overlay/mechaship}"
: "${MECHASHIP_LOCAL_MIRROR_IP:=}"
: "${MECHASHIP_LOCAL_MIRROR_HOSTS:=krr.ports.ubuntu.com krr.ppa.launchpad.net krr.packages.ros.org}"
: "${MECHASHIP_ROS_APT_URI:=http://krr.packages.ros.org/ros2/ubuntu}"
: "${MECHASHIP_VARIANT:=uipa}"

if [[ ! "${MECHASHIP_VARIANT}" =~ ^[a-z0-9_-]+$ ]]; then
	echo "Invalid MECHASHIP_VARIANT=${MECHASHIP_VARIANT}" >&2
	exit 1
fi

variant_config="${MECHASHIP_OVERLAY}/config/variants/${MECHASHIP_VARIANT}.conf"

if [[ ! -f "${variant_config}" ]]; then
	echo "Unknown MECHASHIP_VARIANT=${MECHASHIP_VARIANT}" >&2
	echo "Missing variant config: ${variant_config}" >&2
	exit 1
fi

source "${variant_config}"

: "${MECHASHIP_UDEV_RULE:?MECHASHIP_UDEV_RULE is required}"
: "${MECHASHIP_REPO_BRANCH:?MECHASHIP_REPO_BRANCH is required}"

export MECHASHIP_VARIANT MECHASHIP_UDEV_RULE MECHASHIP_REPO_BRANCH

apt_install() {
	apt-get install -y \
		-o Dpkg::Options::=--force-confdef \
		-o Dpkg::Options::=--force-confold \
		"$@"
}

run_as_mechaship_user() {
	local command="$*"
	su --login --shell /bin/bash "${MECHASHIP_USER}" --command "cd /home/${MECHASHIP_USER} && ${command}"
}

ensure_line() {
	local line="$1"
	local file="$2"

	touch "${file}"
	grep -Fxq "${line}" "${file}" || echo "${line}" >> "${file}"
}

ensure_source_line() {
	local line="$1"
	local file="$2"

	touch "${file}"
	grep -Fxq "${line}" "${file}" || echo "${line}" >> "${file}"
}

install_file() {
	local mode="$1"
	local source="$2"
	local target="$3"

	install -D -m "${mode}" "${source}" "${target}"
}

configure_local_mirror_hosts() {
	local host
	local hosts_line

	[[ -n "${MECHASHIP_LOCAL_MIRROR_IP}" ]] || return 0
	[[ -n "${MECHASHIP_LOCAL_MIRROR_HOSTS}" ]] || return 0

	hosts_line="${MECHASHIP_LOCAL_MIRROR_IP} ${MECHASHIP_LOCAL_MIRROR_HOSTS}"

	for host in ${MECHASHIP_LOCAL_MIRROR_HOSTS}; do
		sed -i "/[[:space:]]${host}\\([[:space:]]\\|$\\)/d" /etc/hosts
	done

	echo "${hosts_line}" >> /etc/hosts
}

remove_local_mirror_hosts() {
	local host

	[[ -n "${MECHASHIP_LOCAL_MIRROR_HOSTS}" ]] || return 0

	for host in ${MECHASHIP_LOCAL_MIRROR_HOSTS}; do
		sed -i "/[[:space:]]${host}\\([[:space:]]\\|$\\)/d" /etc/hosts
	done
}

use_internal_apt_mirrors() {
	local apt_files=()
	local file

	[[ -f /etc/apt/sources.list ]] && apt_files+=("/etc/apt/sources.list")
	while IFS= read -r -d '' file; do
		apt_files+=("${file}")
	done < <(find /etc/apt/sources.list.d -type f \( -name '*.list' -o -name '*.sources' \) -print0 2>/dev/null)

	[[ "${#apt_files[@]}" -gt 0 ]] || return 0

	sed -i \
		-e 's|http://ports.ubuntu.com/ubuntu-ports|http://krr.ports.ubuntu.com/ubuntu-ports|g' \
		-e 's|http://ports.ubuntu.com/|http://krr.ports.ubuntu.com/ubuntu-ports/|g' \
		-e 's|http://ports.ubuntu.com|http://krr.ports.ubuntu.com/ubuntu-ports|g' \
		-e 's|https://ports.ubuntu.com/ubuntu-ports|http://krr.ports.ubuntu.com/ubuntu-ports|g' \
		-e 's|https://ports.ubuntu.com/|http://krr.ports.ubuntu.com/ubuntu-ports/|g' \
		-e 's|https://ports.ubuntu.com|http://krr.ports.ubuntu.com/ubuntu-ports|g' \
		-e 's|http://kr.ports.ubuntu.com/ubuntu-ports|http://krr.ports.ubuntu.com/ubuntu-ports|g' \
		-e 's|http://kr.ports.ubuntu.com/|http://krr.ports.ubuntu.com/ubuntu-ports/|g' \
		-e 's|http://kr.ports.ubuntu.com|http://krr.ports.ubuntu.com/ubuntu-ports|g' \
		-e 's|https://kr.ports.ubuntu.com/ubuntu-ports|http://krr.ports.ubuntu.com/ubuntu-ports|g' \
		-e 's|https://kr.ports.ubuntu.com/|http://krr.ports.ubuntu.com/ubuntu-ports/|g' \
		-e 's|https://kr.ports.ubuntu.com|http://krr.ports.ubuntu.com/ubuntu-ports|g' \
		"${apt_files[@]}"
}

use_public_apt_mirrors() {
	local apt_files=()
	local file

	[[ -f /etc/apt/sources.list ]] && apt_files+=("/etc/apt/sources.list")
	while IFS= read -r -d '' file; do
		apt_files+=("${file}")
	done < <(find /etc/apt/sources.list.d -type f \( -name '*.list' -o -name '*.sources' \) -print0 2>/dev/null)

	[[ "${#apt_files[@]}" -gt 0 ]] || return 0

	sed -i \
		-e 's|http://krr.ports.ubuntu.com/ubuntu-ports|http://ports.ubuntu.com/ubuntu-ports|g' \
		-e 's|http://krr.ports.ubuntu.com|http://ports.ubuntu.com|g' \
		-e 's|http://krr.ppa.launchpad.net|http://ppa.launchpad.net|g' \
		-e 's|http://krr.packages.ros.org|http://packages.ros.org|g' \
		"${apt_files[@]}"
}
