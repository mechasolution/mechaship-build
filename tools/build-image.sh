#!/usr/bin/env bash

set -eEuo pipefail

usage() {
	cat <<-'USAGE'
	Usage:
	  ./tools/build-image.sh [extra compile.sh args...]

	Defaults to:
	  MECHASHIP_VARIANT=v26.01b ./compile.sh build BOARD=<variant board> BRANCH=vendor BUILD_DESKTOP=no BUILD_MINIMAL=no FORCE_USE_RAMDISK=no KERNEL_CONFIGURE=no RELEASE=noble REVISION=<build date>

	Examples:
	  ./tools/build-image.sh
	  MECHASHIP_VARIANT=v26.09b ./tools/build-image.sh
	  MECHASHIP_VARIANT=v26.06a ./tools/build-image.sh
	  REVISION=2026.05.13 ./tools/build-image.sh
	  ./tools/build-image.sh COMPRESS_OUTPUTIMAGE=sha,img
	USAGE
}

script_path="$(readlink -f "$0")"
repo_root="$(cd "$(dirname "${script_path}")/.." && pwd)"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

cd "${repo_root}"

: "${MECHASHIP_VARIANT:=v26.01b}"

if [[ ! "${MECHASHIP_VARIANT}" =~ ^[a-z0-9_-]+(\.[a-z0-9_-]+)*$ ]]; then
	echo "Invalid MECHASHIP_VARIANT=${MECHASHIP_VARIANT}" >&2
	exit 1
fi

variant_config="${repo_root}/userpatches/overlay/mechaship/config/variants/${MECHASHIP_VARIANT}.conf"

if [[ ! -f "${variant_config}" ]]; then
	echo "Unknown MECHASHIP_VARIANT=${MECHASHIP_VARIANT}" >&2
	echo "Missing variant config: ${variant_config}" >&2
	exit 1
fi

source "${variant_config}"
: "${MECHASHIP_BOARD:?MECHASHIP_BOARD is required by ${variant_config}}"

export MECHASHIP_VARIANT
export REVISION="${REVISION:-$(date +%Y.%m.%d)}"

exec ./compile.sh build \
	BOARD="${MECHASHIP_BOARD}" \
	BRANCH=vendor \
	BUILD_DESKTOP=no \
	BUILD_MINIMAL=no \
	FORCE_USE_RAMDISK=no \
	KERNEL_CONFIGURE=no \
	MECHASHIP_VARIANT="${MECHASHIP_VARIANT}" \
	RELEASE=noble \
	"$@"
