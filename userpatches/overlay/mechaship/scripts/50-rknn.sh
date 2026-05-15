#!/bin/bash

source /tmp/overlay/mechaship/scripts/common.sh

apt_install python3-dev python3-pip gcc python3-opencv python3-numpy

cp -a "${MECHASHIP_OVERLAY}/files/rknn-toolkit2/rknn_toolkit_lite2-2.3.0-cp312-cp312-manylinux_2_17_aarch64.manylinux2014_aarch64.whl" "/home/${MECHASHIP_USER}/temp/"
cp -a "${MECHASHIP_OVERLAY}/files/rknn-toolkit2/librknnrt.so" "/home/${MECHASHIP_USER}/temp/"
chown "${MECHASHIP_USER}:${MECHASHIP_USER}" "/home/${MECHASHIP_USER}/temp/"*

run_as_mechaship_user "pip3 install ~/temp/rknn_toolkit_lite2-2.3.0-cp312-cp312-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
install -m 0644 "/home/${MECHASHIP_USER}/temp/librknnrt.so" /usr/lib/librknnrt.so
