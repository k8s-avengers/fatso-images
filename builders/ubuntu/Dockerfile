FROM ubuntu:noble
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y kmod mkosi dpkg-dev devscripts systemd-ukify systemd-boot cpio mtools && apt clean && rm -rf /var/lib/apt/lists

WORKDIR /cache/packages
WORKDIR /out
WORKDIR /work

RUN mkosi --version

VOLUME /cache/packages
VOLUME /out
VOLUME /work
