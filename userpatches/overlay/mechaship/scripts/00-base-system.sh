#!/bin/bash

source /tmp/overlay/mechaship/scripts/common.sh

configure_local_mirror_hosts

if [[ -f /etc/apt/sources.list.d/extra-ppas.list ]]; then
	sed -i 's|http://ppa.launchpad.net|http://krr.ppa.launchpad.net|g' /etc/apt/sources.list.d/extra-ppas.list
fi

use_internal_apt_mirrors

apt-get update
apt_install \
	adduser \
	build-essential \
	ca-certificates \
	cmake \
	curl \
	git \
	gnupg \
	lsb-release \
	net-tools \
	network-manager \
	python3-pip \
	python3-venv \
	software-properties-common \
	sudo

apt-get -y upgrade

apt_install locales

locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
