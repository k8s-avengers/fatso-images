FROM fedora:40

# Proxy handling; will be filled in by bash automatically.
ARG PROXY_NO_PROXY
ARG PROXY_HTTP_PROXY
ARG PROXY_HTTPS_PROXY
ENV no_proxy=$PROXY_NO_PROXY
ENV http_proxy=$PROXY_HTTP_PROXY
ENV https_proxy=$PROXY_HTTPS_PROXY
RUN echo "Dockerfile: Proxy config debugging: no_proxy: ${no_proxy}" && echo "Dockerfile: Proxy config debugging: http_proxy: ${http_proxy}" && echo "Proxy config debugging: https_proxy: ${https_proxy}" && echo "Dockerfile: env proxy debugging: " && env | grep -i proxy

# A customization entrypoint, so users can easily inject their proxies / ca-certificates / etc.
WORKDIR /extra-dockerfile
ADD builder_dockerfile_early.sh /extra-dockerfile/builder_dockerfile_early.sh
RUN bash -e /extra-dockerfile/builder_dockerfile_early.sh

# Yes, this has a huge dependency tree. Hopefully you won't cache miss this too often; reduce your usage of early fragments.
RUN dnf -y install --best --allowerasing jq wget curl tree systemd-ukify systemd-boot systemd-boot-unsigned cpio mtools xfsprogs git kmod mkosi apt dpkg ubu-keyring grub2-efi-x64 grub2-efi-x64-modules grub2-tools grub2-tools-efi grub2-tools-extra qemu-img

WORKDIR /cache/packages
WORKDIR /out
WORKDIR /work

# Install mkosi from source -- the version in the Ubuntu repos is too old
WORKDIR /mkosi-src

# Grab mkosi sources from GitHub Releases
#
RUN wget --no-check-certificate -O mkosi.tar.gz https://github.com/systemd/mkosi/archive/refs/tags/v23.1.tar.gz
RUN tar xzf mkosi.tar.gz && rm -f mkosi.tar.gz
RUN ln -s mkosi-* mkosi
RUN ls -la

# Make it local
RUN ln -s /mkosi-src/mkosi/bin/mkosi /usr/local/bin/mkosi
RUN echo -n 'local mkosi version: ' && /usr/local/bin/mkosi --version

# Another customization entrypoint, who knows what might be needed
WORKDIR /extra-dockerfile
ADD builder_dockerfile_late.sh /extra-dockerfile/builder_dockerfile_late.sh
RUN bash -e /extra-dockerfile/builder_dockerfile_late.sh

VOLUME /cache/packages
VOLUME /out
VOLUME /work

# Important!
WORKDIR /work
