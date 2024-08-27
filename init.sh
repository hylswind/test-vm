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
    mkdir /instance-store
    mount /dev/nvme1n1 /instance-store
else
    echo "/dev/nvme1n1 does not exist."
    false
fi

# load config from user-data
METADATA_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
CONFIG_JSON=$(curl -s -H "X-aws-ec2-metadata-token: $METADATA_TOKEN" http://169.254.169.254/latest/user-data | sed -n '/<<COMMENT/,/COMMENT/p' | sed '1d;$d')
CONFIG_USE_GPU=$(echo $CONFIG_JSON | jq -r .useGPU)
CONFIG_CONTAINER_IMAGE=$(echo $CONFIG_JSON | jq -r .containerImage)
CONFIG_CONTAINER_ARGS=$(echo $CONFIG_JSON | jq -r .containerArgs)

# install GPU driver and toolkit
if [ $CONFIG_USE_GPU == "true" ]; then
  dnf install -y dkms kernel-devel kernel-modules-extra

  dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/cuda-amzn2023.repo
  dnf clean expire-cache
  dnf module install -y nvidia-driver:latest-dkms
  dnf install -y cuda-toolkit

  nvidia-smi
  /usr/local/cuda/bin/nvcc --version

  dnf config-manager --add-repo https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo
  dnf clean expire-cache
  dnf install -y nvidia-container-toolkit
fi

# install docker images
dnf install -y docker
nvidia-ctk runtime configure --runtime=docker

if [ $CONFIG_USE_GPU == "true" ]; then
  nvidia-ctk runtime configure --runtime=docker
fi

systemctl restart docker

# Change the container storage to instance store
