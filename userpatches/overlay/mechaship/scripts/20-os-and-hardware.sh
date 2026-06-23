#!/bin/bash

source /tmp/overlay/mechaship/scripts/common.sh

apt_install neofetch

set_os_release_value() {
	local key="$1"
	local value="$2"
	local file="/etc/os-release"

	if grep -q "^${key}=" "${file}"; then
		sed -i "s|^${key}=.*|${key}=${value}|" "${file}"
	else
		echo "${key}=${value}" >> "${file}"
	fi
}

mechaship_pretty_name="MechaShip OS with Ubuntu 24.04.4 LTS"
armbian_pretty_name="$(grep -E '^ARMBIAN_PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- || true)"

if [[ -z "${armbian_pretty_name}" && -f /etc/armbian-release ]]; then
	# shellcheck disable=SC1091
	source /etc/armbian-release
	armbian_pretty_name="\"${VENDOR:-Armbian} ${VERSION:-unknown} ${DISTRIBUTION_CODENAME:-noble}\""
fi

set_os_release_value "PRETTY_NAME" "\"${mechaship_pretty_name}\""
set_os_release_value "NAME" "\"Ubuntu\""
set_os_release_value "VERSION_ID" "\"24.04\""
set_os_release_value "VERSION" "\"24.04 LTS (Noble Numbat)\""
set_os_release_value "VERSION_CODENAME" "noble"
set_os_release_value "ID" "ubuntu"
set_os_release_value "ID_LIKE" "debian"
set_os_release_value "HOME_URL" "\"https://bluexrobotics.kr\""
set_os_release_value "SUPPORT_URL" "\"https://forums.bluexrobotics.kr\""
set_os_release_value "BUG_REPORT_URL" "\"https://bluexrobotics.kr/bugs\""
set_os_release_value "PRIVACY_POLICY_URL" "\"https://bluexrobotics.kr\""
set_os_release_value "UBUNTU_CODENAME" "noble"
set_os_release_value "LOGO" "\"armbian-logo\""

if [[ -n "${armbian_pretty_name}" ]]; then
	set_os_release_value "ARMBIAN_PRETTY_NAME" "${armbian_pretty_name}"
fi

cat > /etc/lsb-release <<EOF
DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=24.04
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="${mechaship_pretty_name}"
EOF

if [[ "${BOARD:-}" != "rock-5a" ]]; then
	echo "Skipping Rock 5A cooling fan device tree customization for BOARD=${BOARD:-unknown}"
	exit 0
fi

apt_install device-tree-compiler

overlay_dts="/tmp/mechaship-rock5a-fan.dts"
overlay_dtbo="/tmp/mechaship-rock5a-fan.dtbo"

cleanup_device_tree_files() {
	rm -f "${overlay_dts}" "${overlay_dtbo}"
}

trap cleanup_device_tree_files EXIT

cat > "${overlay_dts}" <<'EOF'
/dts-v1/;
/plugin/;

/ {
	compatible = "rockchip,rk3588s";

	fragment@0 {
		target = <&pwm15>;
		__overlay__ {
			pinctrl-names = "active";
			pinctrl-0 = <&pwm15m3_pins>;
			status = "okay";
		};
	};

	fragment@1 {
		target = <&fan0>;
		__overlay__ {
			cooling-levels = <0 50 101 152 204 255>;
			pwms = <&pwm15 0 10000 0>;
		};
	};

	/* Six cooling levels have valid state indexes 0 through 5. */
	fragment@2 {
		target = <&soc_thermal>;
		__overlay__ {
			cooling-maps {
				map5 {
					cooling-device = <&fan0 5 5>;
				};
			};
		};
	};
};
EOF

dtc -@ -I dts -O dtb "${overlay_dts}" -o "${overlay_dtbo}"

mapfile -t rock5a_dtbs < <(find /boot -type f -path '*/rockchip/rk3588s-rock-5a.dtb' | sort)

if [[ "${#rock5a_dtbs[@]}" -eq 0 ]]; then
	echo "No rk3588s-rock-5a.dtb found under /boot" >&2
	exit 1
fi

for dtb in "${rock5a_dtbs[@]}"; do
	backup="${dtb}.mechaship-orig"
	patched="${dtb}.mechaship-new"

	if [[ ! -f "${backup}" ]]; then
		cp -a "${dtb}" "${backup}"
	fi

	fdtoverlay -i "${dtb}" -o "${patched}" "${overlay_dtbo}"
	chmod --reference="${dtb}" "${patched}"
	chown --reference="${dtb}" "${patched}"
	touch --reference="${dtb}" "${patched}"
	mv -f "${patched}" "${dtb}"
	echo "Applied MechaShip Rock 5A cooling fan overlay to ${dtb}"
done
