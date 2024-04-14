FROM ubuntu:noble
ENV DEBIAN_FRONTEND=noninteractive

# A customization entrypoint, so users can easily inject their proxies / ca-certificates / etc.
WORKDIR /extra-dockerfile
ADD early-init.docker.sh /extra-dockerfile/early-init.docker.sh
RUN bash -e /extra-dockerfile/early-init.docker.sh

RUN apt-get update && apt-get install -y xfsprogs git kmod mkosi dpkg-dev devscripts grub-efi cpio mtools

WORKDIR /cache/packages
WORKDIR /out
WORKDIR /work

RUN echo -n 'system mkosi version: ' && mkosi --version

# Install mkosi from source -- the version in the Ubuntu repos is too old
WORKDIR /mkosi-src
RUN git clone "https://github.com/systemd/mkosi" && cd mkosi && git checkout "7a817f3a808240e84aad9d18131c50af5897741e" # Specific master revision proven to work 
RUN ln -s /mkosi-src/mkosi/bin/mkosi /usr/local/bin/mkosi
RUN echo -n 'local mkosi version: ' && /usr/local/bin/mkosi --version

VOLUME /cache/packages
VOLUME /out
VOLUME /work

# Important!
WORKDIR /work
