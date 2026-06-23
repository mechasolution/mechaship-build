#!/bin/bash

source /tmp/overlay/mechaship/scripts/common.sh

configure_local_mirror_hosts

add-apt-repository -y universe
curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
	-o /usr/share/keyrings/ros-archive-keyring.gpg

cat > /etc/apt/sources.list.d/ros2.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] ${MECHASHIP_ROS_APT_URI} $(. /etc/os-release && echo "${UBUNTU_CODENAME}") main
EOF

apt-get update
apt_install ros-jazzy-ros-base ros-dev-tools python3-pip
python3 -m pip config set global.break-system-packages true
run_as_mechaship_user "python3 -m pip config set global.break-system-packages true"

run_as_mechaship_user "mkdir -p ~/ros2_ws/src && source /opt/ros/jazzy/setup.bash && cd ~/ros2_ws && colcon build"

if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
	rosdep init
fi
run_as_mechaship_user "rosdep update"

cat >> "/home/${MECHASHIP_USER}/.bashrc" <<'EOF'
source /opt/ros/jazzy/setup.bash
alias cb='cd ~/ros2_ws && colcon build --symlink-install && source ~/ros2_ws/install/local_setup.bash'
source ~/ros2_ws/install/setup.bash
export ROS_DOMAIN_ID=0
EOF

chown "${MECHASHIP_USER}:${MECHASHIP_USER}" "/home/${MECHASHIP_USER}/.bashrc"
