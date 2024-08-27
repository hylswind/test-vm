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

# load config from user-data
METADATA_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
VSE_CONFIG=$(curl -s -H "X-aws-ec2-metadata-token: $METADATA_TOKEN" http://169.254.169.254/latest/user-data | sed -n '/<<COMMENT/,/COMMENT/p' | sed '1d;$d')

echo $VSE_CONFIG
echo "Test Done"
