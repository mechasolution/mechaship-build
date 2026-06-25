#!/usr/bin/env bash

set -eEuo pipefail

usage() {
	cat <<-'USAGE'
	Usage:
	  ./tools/build-image.sh [extra compile.sh args...]

	Defaults to:
	  MECHASHIP_VARIANT=v26.01b ./compile.sh build BOARD=rock-5a BRANCH=vendor BUILD_DESKTOP=no BUILD_MINIMAL=no KERNEL_CONFIGURE=no RELEASE=noble REVISION=<build date>

	Examples:
	  ./tools/build-image.sh
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

export REVISION="${REVISION:-$(date +%Y.%m.%d)}"

exec ./compile.sh build \
	BOARD=rock-5a \
	BRANCH=vendor \
	BUILD_DESKTOP=no \
	BUILD_MINIMAL=no \
	KERNEL_CONFIGURE=no \
	RELEASE=noble \
	"$@"
