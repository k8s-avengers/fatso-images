FROM ubuntu:noble
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y kmod mkosi dpkg-dev devscripts systemd-ukify systemd-boot
RUN apt-get install -y 

WORKDIR /out
WORKDIR /src

RUN mkosi --version

VOLUME /out
VOLUME /src
