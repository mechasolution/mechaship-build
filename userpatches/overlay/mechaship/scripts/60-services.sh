#!/bin/bash

source /tmp/overlay/mechaship/scripts/common.sh

service_source="${MECHASHIP_OVERLAY}/files/mechaship_system/.mechaship_system_service"
service_home="/home/${MECHASHIP_USER}/.mechaship_system_service"

if [[ ! -d "${service_source}" ]]; then
	echo "Missing MechaShip system service payload: ${service_source}" >&2
	exit 1
fi

rm -rf "${service_home}"
cp -a "${service_source}" "/home/${MECHASHIP_USER}/"
chown -R "${MECHASHIP_USER}:${MECHASHIP_USER}" "${service_home}"

install -D -m 0644 "${MECHASHIP_OVERLAY}/files/systemd/mechaship_system.service" /etc/systemd/system/mechaship_system.service
install -D -m 0644 "${MECHASHIP_OVERLAY}/files/systemd/mechaship_power_off.service" /etc/systemd/system/mechaship_power_off.service

if [[ "${MECHASHIP_USER}" != "ubuntu" ]]; then
	sed -i "s|/home/ubuntu|/home/${MECHASHIP_USER}|g" \
		/etc/systemd/system/mechaship_system.service \
		/etc/systemd/system/mechaship_power_off.service
fi

apt_install python3-pip python3-venv socat iw
python3 -m venv "${service_home}/venv"
"${service_home}/venv/bin/pip" install \
	-r "${service_home}/requirements.txt"
chown -R "${MECHASHIP_USER}:${MECHASHIP_USER}" "${service_home}/venv"

systemctl enable mechaship_system.service
systemctl enable mechaship_power_off.service

pip3 install ping3 --break-system-packages
ln -sf "${service_home}/mechaship_battery.sh" /usr/local/bin/mechaship_battery
chmod 0755 /usr/local/bin/mechaship_battery
