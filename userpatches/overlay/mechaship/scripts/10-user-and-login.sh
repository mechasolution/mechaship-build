#!/bin/bash

source /tmp/overlay/mechaship/scripts/common.sh

if ! id "${MECHASHIP_USER}" >/dev/null 2>&1; then
	adduser --gecos "${MECHASHIP_REALNAME},,," --disabled-password --shell /bin/bash "${MECHASHIP_USER}"
fi

echo "${MECHASHIP_USER}:${MECHASHIP_PASSWORD}" | chpasswd

for group in sudo dialout video render input gpio i2c spi; do
	getent group "${group}" >/dev/null || groupadd --system "${group}"
	usermod -aG "${group}" "${MECHASHIP_USER}"
done

install -d -m 0755 /etc/sudoers.d
cat > "/etc/sudoers.d/90-${MECHASHIP_USER}-nopasswd" <<EOF
${MECHASHIP_USER} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 "/etc/sudoers.d/90-${MECHASHIP_USER}-nopasswd"

install -d -o "${MECHASHIP_USER}" -g "${MECHASHIP_USER}" "/home/${MECHASHIP_USER}/temp"

install -d -m 0755 /usr/local/sbin
cat > /usr/local/sbin/mechaship-clear-console <<'EOF'
#!/bin/sh

tty_name="${1:-tty1}"

case "${tty_name}" in
	tty[0-9]*)
		;;
	*)
		exit 0
		;;
esac

tty_path="/dev/${tty_name}"
if [ -w "${tty_path}" ]; then
	printf '\033c\033[3J\033[H\033[2J' > "${tty_path}"
fi
EOF
chmod 0755 /usr/local/sbin/mechaship-clear-console

install -d -m 0755 /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/10-mechaship-clear.conf <<'EOF'
[Service]
TTYVTDisallocate=yes
ExecStartPre=-/usr/local/sbin/mechaship-clear-console %I
EOF

netplan_source="${MECHASHIP_OVERLAY}/files/netplan/${MECHASHIP_NETPLAN_FILE}"

if [[ ! -f "${netplan_source}" ]]; then
	echo "Missing MechaShip netplan configuration: ${netplan_source}" >&2
	exit 1
fi

install -D -m 0600 "${netplan_source}" "/etc/netplan/${MECHASHIP_NETPLAN_FILE}"

install -D -m 0755 \
	"${MECHASHIP_OVERLAY}/files/bin/mechaship-rock5c-selftest" \
	/usr/local/bin/mechaship-rock5c-selftest

if [[ -d /etc/cloud/cloud.cfg.d ]]; then
	cat > /etc/cloud/cloud.cfg.d/91-disable-default-user.cfg <<'EOF'
#cloud-config
system_info:
  default_user: {}
EOF
fi

rm -f /root/.not_logged_in_yet

apt_install gdisk libcap2-bin openssh-server

install -d -m 0755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/90-mechaship-password-auth.conf <<'EOF'
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
EOF

echo "${MECHASHIP_HOSTNAME_PREFIX}" > /etc/hostname.tpl
chmod 0644 /etc/hostname.tpl

cat > /usr/local/sbin/mechaship-firstboot-hostname <<'EOF'
#!/bin/bash

set -eu

state_dir="/var/lib/mechaship"
state_file="${state_dir}/hostname-initialized"
template_file="/etc/hostname.tpl"
service_file="/etc/systemd/system/mechaship-firstboot-hostname.service"
script_file="/usr/local/sbin/mechaship-firstboot-hostname"

cleanup_firstboot_hostname() {
	systemctl disable mechaship-firstboot-hostname.service >/dev/null 2>&1 || true
	rm -f "${service_file}" "${script_file}"
	systemctl daemon-reload >/dev/null 2>&1 || true
}

if [[ -e "${state_file}" ]]; then
	cleanup_firstboot_hostname
	exit 0
fi

prefix="mechaship-"
if [[ -s "${template_file}" ]]; then
	prefix="$(tr -d '\r\n' < "${template_file}")"
fi

suffix="$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 6)"
hostname="${prefix}${suffix}"

echo "${hostname}" > /etc/hostname
hostname "${hostname}" || true
hostnamectl set-hostname "${hostname}" || true

if command -v setcap >/dev/null 2>&1 && [[ -x /usr/bin/ping ]]; then
	setcap cap_net_raw+ep /usr/bin/ping || true
fi

install -d -m 0755 "${state_dir}"
touch "${state_file}"
cleanup_firstboot_hostname
EOF
chmod 0755 /usr/local/sbin/mechaship-firstboot-hostname

cat > /etc/systemd/system/mechaship-firstboot-hostname.service <<'EOF'
[Unit]
Description=Initialize Mechaship hostname
DefaultDependencies=no
After=local-fs.target
Before=network-pre.target systemd-hostnamed.service
Wants=network-pre.target
ConditionPathExists=!/var/lib/mechaship/hostname-initialized

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/mechaship-firstboot-hostname

[Install]
WantedBy=sysinit.target
EOF

systemctl enable mechaship-firstboot-hostname.service

# A raw image written to a larger SD card retains its original backup GPT
# header location.  Armbian expands the root partition on the first boot, but
# fdisk does not relocate that backup header.  Repair it immediately after the
# resize service so every later boot sees a consistent GPT.
cat > /usr/local/sbin/mechaship-repair-gpt <<'EOF'
#!/bin/bash

set -euo pipefail

state_dir="/var/lib/mechaship"
state_file="${state_dir}/gpt-repaired"
service_name="mechaship-repair-gpt.service"

if [[ -e "${state_file}" ]]; then
	systemctl disable "${service_name}" >/dev/null 2>&1 || true
	exit 0
fi

root_device="$(findmnt -n -o SOURCE / | sed 's~\[.*\]~~')"
disk_name="$(lsblk -n -o PKNAME "${root_device}" | head -n1)"

if [[ -z "${disk_name}" || ! -b "/dev/${disk_name}" ]]; then
	echo "Unable to resolve root disk from ${root_device}" >&2
	exit 1
fi

disk_device="/dev/${disk_name}"
sgdisk -e "${disk_device}"
partprobe "${disk_device}" || true

verification="$(sgdisk -v "${disk_device}" 2>&1 || true)"
if [[ "${verification}" != *'No problems found.'* ]]; then
	echo "GPT verification failed for ${disk_device}" >&2
	echo "${verification}" >&2
	exit 1
fi

install -d -m 0755 "${state_dir}"
touch "${state_file}"
systemctl disable "${service_name}" >/dev/null 2>&1 || true
EOF
chmod 0755 /usr/local/sbin/mechaship-repair-gpt

cat > /etc/systemd/system/mechaship-repair-gpt.service <<'EOF'
[Unit]
Description=Repair backup GPT header after first-boot root expansion
DefaultDependencies=no
After=local-fs.target armbian-resize-filesystem.service
Before=basic.target
ConditionPathExists=!/var/lib/mechaship/gpt-repaired

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/mechaship-repair-gpt
TimeoutStartSec=2min

[Install]
WantedBy=basic.target
EOF

systemctl enable mechaship-repair-gpt.service

if [[ -x /usr/bin/ping ]]; then
	setcap cap_net_raw+ep /usr/bin/ping || true
fi

apt_install \
	landscape-common \
	update-notifier-common \
	ubuntu-pro-client

cat > /etc/ssh/sshd_config.d/91-mechaship-motd.conf <<'EOF'
UsePAM yes
PrintMotd no
PrintLastLog yes
EOF

ensure_pam_motd_line() {
	local line="$1"
	local file="/etc/pam.d/sshd"

	touch "${file}"
	grep -Fqx "${line}" "${file}" || echo "${line}" >> "${file}"
}

ensure_pam_motd_line "session    optional     pam_motd.so  motd=/run/motd.dynamic"
ensure_pam_motd_line "session    optional     pam_motd.so noupdate"

install -d -m 0755 /etc/update-motd.d
cat > /etc/update-motd.d/00-mechaship-banner <<'EOF'
#!/bin/sh
blue="$(printf '\033[1;34m')"
green="$(printf '\033[1;32m')"
reset="$(printf '\033[0m')"

while IFS= read -r line; do
  left="${line%%@@*}"
  right="${line#*@@}"
  printf '%s%s%s%s%s\n' "${blue}" "${left}" "${green}" "${right}" "${reset}"
done <<'BANNER'
___  ___          _           _____ _     _       @@  _____ _____ 
|  \/  |         | |         /  ___| |   (_)      @@ |  _  /  ___|
| .  . | ___  ___| |__   __ _\ `--.| |__  _ _ __  @@ | | | \ `--. 
| |\/| |/ _ \/ __| '_ \ / _` |`--. \ '_ \| | '_ \ @@ | | | |`--. \
| |  | |  __/ (__| | | | (_| /\__/ / | | | | |_) |@@ \ \_/ /\__/ /
\_|  |_/\___|\___|_| |_|\__,_\____/|_| |_|_| .__/ @@  \___/\____/ 
                                           | |    @@              
                                           |_|    @@               
BANNER
EOF
chmod 0755 /etc/update-motd.d/00-mechaship-banner

if [[ -d /etc/update-motd.d ]]; then
	chmod +x /etc/update-motd.d/00-header 2>/dev/null || true
	chmod +x /etc/update-motd.d/10-help-text 2>/dev/null || true
	chmod +x /etc/update-motd.d/50-landscape-sysinfo 2>/dev/null || true
	chmod +x /etc/update-motd.d/90-updates-available 2>/dev/null || true
	chmod +x /etc/update-motd.d/91-release-upgrade 2>/dev/null || true
	chmod +x /etc/update-motd.d/91-contract-ua-esm-status 2>/dev/null || true
	chmod +x /etc/update-motd.d/92-unattended-upgrades 2>/dev/null || true
	chmod +x /etc/update-motd.d/95-hwe-eol 2>/dev/null || true
	chmod +x /etc/update-motd.d/98-fsck-at-reboot 2>/dev/null || true
	chmod +x /etc/update-motd.d/98-reboot-required 2>/dev/null || true
fi
