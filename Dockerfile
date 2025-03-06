FROM nvidia/cuda:11.8.0-devel-ubuntu22.04

RUN apt-get update && apt-get install -y sudo git vim lsb-release software-properties-common

COPY install_deps.sh /install_deps.sh
RUN chmod +x /install_deps.sh
RUN /install_deps.sh
ENV PATH="$PATH:/usr/local/cuda/bin"
