#!/bin/bash

source /tmp/overlay/mechaship/scripts/common.sh

run_as_mechaship_user '
set -e
source ~/ros2_setup.bash
rm -rf ~/uros_ws
mkdir -p ~/uros_ws/src
cd ~/uros_ws
git clone -b "${ROS_DISTRO}" https://github.com/micro-ROS/micro_ros_setup.git src/micro_ros_setup
rosdep install --from-paths src --ignore-src -y
colcon build
source install/local_setup.bash
ros2 run micro_ros_setup create_agent_ws.sh
ros2 run micro_ros_setup build_agent.sh
'
