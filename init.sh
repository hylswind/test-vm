#!/bin/bash
set -e

error_handler () {
    echo "An error occurred. Initiating shutdown..."
    shutdown now
}

trap error_handler ERR

# prepare nvme device
if [ -e /dev/nvme1n1 ]; then
    mkfs -t xfs /dev/nvme1n1
    mkdir /home/ec2-user/instance-store
    mount /dev/nvme1n1 /home/ec2-user/instance-store
    chown -R ec2-user:ec2-user /home/ec2-user/instance-store
else
    echo "/dev/nvme1n1 does not exist."
    false
fi
