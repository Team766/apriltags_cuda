#!/bin/bash


install_cuda_x86() {
	wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
	sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
	wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda-repo-ubuntu2204-11-8-local_11.8.0-520.61.05-1_amd64.deb
	sudo dpkg -i cuda-repo-ubuntu2204-11-8-local_11.8.0-520.61.05-1_amd64.deb
	sudo cp /var/cuda-repo-ubuntu2204-11-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
	sudo apt-get update
	sudo apt-get -y install cuda-11-8
}

install_cuda_jetson() {
	wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/arm64/cuda-ubuntu2004.pin
	sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
	wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda-tegra-repo-ubuntu2004-11-8-local_11.8.0-1_arm64.deb
	sudo dpkg -i cuda-tegra-repo-ubuntu2004-11-8-local_11.8.0-1_arm64.deb
	sudo cp /var/cuda-tegra-repo-ubuntu2004-11-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
	sudo apt-get update
	sudo apt-get -y install cuda-11-8
}

install_llvm() {
	wget https://apt.llvm.org/llvm.sh
	chmod +x llvm.sh
	sudo ./llvm.sh 17
}

export DEBIAN_FRONTEND=noninteractive

sudo apt update -y
sudo apt install -y wget build-essential cmake python3-dev python3-numpy libprotobuf-dev protobuf-compiler
sudo apt install -y libgoogle-glog-dev libgtest-dev libssh-dev libxrandr-dev libxinerama-dev libstdc++-12-dev
sudo apt install -y golang

# Check if clang-17 is installed.
if ! dpkg -l | grep clang-17; then
	install_llvm
fi

# Check if cuda-toolkit is installed
if dpkg -l | grep -q cuda-toolkit-11-8; then
	echo "cuda-toolkit 11-8 is installed."
	exit 0
fi

arch=$(uname -m)
case $arch in
    x86_64)
        echo "Installing cuda on x86"
        install_cuda_x86
        ;;
    aarch64)
        case $(cat /proc/cpuinfo) in
	    *0xd42*)
                echo "Installing cuda on jetson"
                install_cuda_jetson
                ;;    
	    *)
                echo "Device is not detected to be Jetson Orin Nano; Not installing CUDA."
	        ;;
        esac
	;;
    *)
        echo "Unknown architecture: $arch"
        # Handle unknown architecture here
        ;;
esac


