#!/bin/bash

source /tmp/overlay/mechaship/scripts/common.sh

use_public_apt_mirrors
remove_local_mirror_hosts

apt-get -y clean
apt-get -y autoclean
apt-get -y autoremove

if [[ "${MECHASHIP_EXPIRE_PASSWORD}" == "yes" ]]; then
	chage -d 0 "${MECHASHIP_USER}"
fi
