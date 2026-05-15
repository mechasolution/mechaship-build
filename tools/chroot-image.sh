#!/usr/bin/env bash

set -eEuo pipefail

usage() {
	cat <<-'USAGE'
	Usage:
	  ./tools/chroot-image.sh latest
	  ./tools/chroot-image.sh output/images/Armbian-....img
	  CHROOT_IMAGE_USER=root ./tools/chroot-image.sh latest

	Opens the root filesystem from a built image in a chroot shell as ubuntu.
	When the shell exits, changes remain in the source .img.
	USAGE
}

script_path="$(readlink -f "$0")"
repo_root="$(cd "$(dirname "${script_path}")/.." && pwd)"

target="${1:-latest}"
if [[ "${target}" == "-h" || "${target}" == "--help" ]]; then
	usage
	exit 0
fi

if [[ "${EUID}" -ne 0 ]]; then
	exec sudo --preserve-env=PATH "${script_path}" "$@"
fi

cd "${repo_root}"

if [[ "${target}" == "latest" ]]; then
	target="$(find output/images -maxdepth 1 -type f -name '*.img' -printf '%T@ %p\n' 2> /dev/null | sort -nr | awk 'NR == 1 {print $2}')"
	[[ -n "${target}" ]] || {
		echo "No output/images/*.img found. Build an uncompressed image first." >&2
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

require_command() {
	command -v "$1" > /dev/null || {
		echo "Missing required command: $1" >&2
		exit 1
	}
}

for command_name in losetup lsblk mount umount chroot awk find sort readlink; do
	require_command "${command_name}"
done

workdir="$(mktemp -d "${repo_root}/.tmp/chroot-image.XXXXXXXX")"
mountdir="${workdir}/mnt"
loopdev=""
qemu_copied=""
chroot_user="${CHROOT_IMAGE_USER:-ubuntu}"

cleanup_mounts() {
	set +e
	if [[ -n "${mountdir:-}" && -d "${mountdir}" ]]; then
		umount "${mountdir}/dev/pts" 2> /dev/null || true
		umount "${mountdir}/dev" 2> /dev/null || true
		umount "${mountdir}/proc" 2> /dev/null || true
		umount "${mountdir}/sys" 2> /dev/null || true
		umount "${mountdir}/run" 2> /dev/null || true
		umount "${mountdir}" 2> /dev/null || true
	fi
	if [[ -n "${loopdev:-}" ]]; then
		losetup -d "${loopdev}" 2> /dev/null || true
	fi
}

cleanup_all() {
	if [[ "${qemu_copied:-}" == "yes" && -n "${mountdir:-}" && -d "${mountdir}" ]]; then
		rm -f "${mountdir}/usr/bin/qemu-aarch64-static" 2> /dev/null || true
	fi
	cleanup_mounts
	rm -rf "${workdir}"
}

trap cleanup_all EXIT

image_path="${target}"
image_basename="$(basename "${image_path}")"

mkdir -p "${mountdir}"
loopdev="$(losetup --show --partscan --find "${image_path}")"
udevadm settle 2> /dev/null || true
partprobe "${loopdev}" 2> /dev/null || true
sleep 1

root_part="$(
	lsblk -b -nrpo NAME,FSTYPE,SIZE "${loopdev}" |
		awk '$2 ~ /^(ext[234]|btrfs|xfs|f2fs)$/ { if ($3 > size) { size = $3; name = $1 } } END { print name }'
)"

if [[ -z "${root_part}" || ! -b "${root_part}" ]]; then
	echo "Could not find a supported root filesystem partition in ${image_basename}." >&2
	lsblk "${loopdev}" >&2 || true
	exit 1
fi

echo "Mounting ${root_part}..."
mount "${root_part}" "${mountdir}"
mount -t proc proc "${mountdir}/proc"
mount -t sysfs sysfs "${mountdir}/sys"
mount --bind /dev "${mountdir}/dev"
mount -t devpts devpts "${mountdir}/dev/pts" || mount --bind /dev/pts "${mountdir}/dev/pts"
mount --bind /run "${mountdir}/run"

target_arch="$(file -b "${mountdir}/bin/bash" 2> /dev/null || true)"
if [[ "$(uname -m)" == "x86_64" && "${target_arch}" == *"ARM aarch64"* && ! -e "${mountdir}/usr/bin/qemu-aarch64-static" ]]; then
	if [[ -x /usr/bin/qemu-aarch64-static ]]; then
		cp -a /usr/bin/qemu-aarch64-static "${mountdir}/usr/bin/qemu-aarch64-static"
		qemu_copied="yes"
	else
		echo "Warning: /usr/bin/qemu-aarch64-static is missing; chroot may fail on this host." >&2
	fi
fi

echo
echo "Entered image chroot: ${image_basename} (${chroot_user})"
echo "Type 'exit' to unmount the image."
echo

set +e
if [[ "${chroot_user}" == "root" ]]; then
	chroot "${mountdir}" /usr/bin/env bash -l
else
	chroot "${mountdir}" /usr/bin/env bash -lc "id -u '${chroot_user}' > /dev/null && exec su - '${chroot_user}'"
fi
chroot_rc=$?
set -e

if [[ "${qemu_copied}" == "yes" ]]; then
	rm -f "${mountdir}/usr/bin/qemu-aarch64-static"
fi

sync
cleanup_mounts
loopdev=""

if [[ -f "${target}.sha" ]]; then
	(
		cd "$(dirname "${target}")"
		sha256sum -b "$(basename "${target}")" > "$(basename "${target}").sha"
	)
fi

if [[ -n "${SUDO_UID:-}" && -n "${SUDO_GID:-}" ]]; then
	chown "${SUDO_UID}:${SUDO_GID}" "${target}" "${target}.sha" 2> /dev/null || true
fi

echo "Updated ${target}"
exit "${chroot_rc}"
