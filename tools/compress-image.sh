#!/usr/bin/env bash

set -eEuo pipefail

usage() {
	cat <<-'USAGE'
	Usage:
	  ./tools/compress-image.sh latest
	  ./tools/compress-image.sh output/images/Armbian-....img

	Compresses a built .img into .img.zip with pigz -K and writes .img.zip.sha256.
	The source .img is removed by pigz after successful compression.
	USAGE
}

script_path="$(readlink -f "$0")"
repo_root="$(cd "$(dirname "${script_path}")/.." && pwd)"

target="${1:-latest}"
if [[ "${target}" == "-h" || "${target}" == "--help" ]]; then
	usage
	exit 0
fi

cd "${repo_root}"

if [[ "${target}" == "latest" ]]; then
	target="$(find output/images -maxdepth 1 -type f -name '*.img' -printf '%T@ %p\n' 2> /dev/null | sort -nr | awk 'NR == 1 {print $2}')"
	[[ -n "${target}" ]] || {
		echo "No output/images/*.img found." >&2
		exit 1
	}
fi

target="$(readlink -f "${target}")"
[[ -f "${target}" ]] || {
	echo "Image not found: ${target}" >&2
	exit 1
}
[[ "${target}" == *.img ]] || {
	echo "Expected a .img file: ${target}" >&2
	exit 1
}

for command_name in pigz sha256sum; do
	command -v "${command_name}" > /dev/null || {
		echo "Missing required command: ${command_name}" >&2
		exit 1
	}
done

target_dir="$(dirname "${target}")"
target_base="$(basename "${target}")"
archive="${target}.zip"

if [[ -e "${archive}" ]]; then
	echo "Refusing to overwrite existing archive: ${archive}" >&2
	exit 1
fi

echo "Compressing ${target_base}..."
(
	cd "${target_dir}"
	pigz -K "${target_base}"
	sha256sum -b "${target_base}.zip" > "${target_base}.zip.sha256"
	rm -f "${target_base}.sha"
)

echo "Created ${archive}"
