#!/bin/bash

source /tmp/overlay/mechaship/scripts/common.sh

install -D -m 0644 \
	"${MECHASHIP_OVERLAY}/files/udev/${MECHASHIP_UDEV_RULE}" \
	"/etc/udev/rules.d/${MECHASHIP_UDEV_RULE}"

apt_install \
	ros-jazzy-cartographer \
	ros-jazzy-cartographer-ros \
	ros-jazzy-cv-bridge \
	ros-jazzy-robot-localization \
	ros-jazzy-ros-gz \
	ros-jazzy-slam-toolbox \
	ros-jazzy-ublox-gps \
	ros-jazzy-usb-cam \
	ros-jazzy-vision-msgs

run_as_mechaship_user "
set -e
source ~/ros2_setup.bash
rm -rf ~/YDLidar-SDK
git clone https://github.com/YDLIDAR/YDLidar-SDK ~/YDLidar-SDK
cd ~/YDLidar-SDK
mkdir -p build
cd build
cmake ..
make -j\$(nproc)
sudo make install
rm -rf ~/ros2_ws/src/mechaship
git clone --recurse-submodules -b '${MECHASHIP_REPO_BRANCH}' --depth=1 --shallow-submodules https://github.com/mechasolution/mechaship.git ~/ros2_ws/src/mechaship
cd ~/ros2_ws
rosdep install --from-paths src --ignore-src -y --skip-keys=ros_wit_imu_node
colcon build --symlink-install
"
