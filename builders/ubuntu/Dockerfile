FROM ubuntu:noble
ENV DEBIAN_FRONTEND=noninteractive

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
RUN apt-get update && apt-get install -y jq wget curl tree reprepro xfsprogs git kmod mkosi dpkg-dev devscripts grub-efi systemd-ukify systemd-boot cpio mtools

WORKDIR /cache/packages
WORKDIR /out
WORKDIR /work

RUN echo -n 'system mkosi version: ' && mkosi --version

# Install mkosi from source -- the version in the Ubuntu repos is too old
WORKDIR /mkosi-src
RUN git clone "https://github.com/systemd/mkosi" && cd mkosi && git checkout "efcef5e3d99420d7365c4d3d2328beb3636e897a" # Specific master revision proven to work 
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
