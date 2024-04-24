FROM fedora:40

# A customization entrypoint, so users can easily inject their proxies / ca-certificates / etc.
WORKDIR /extra-dockerfile
ADD builder_dockerfile_early.sh /extra-dockerfile/builder_dockerfile_early.sh
RUN bash -e /extra-dockerfile/builder_dockerfile_early.sh

RUN dnf -y install --best --allowerasing jq wget curl tree systemd-ukify systemd-boot systemd-boot-unsigned cpio mtools xfsprogs git kmod mkosi apt dpkg ubu-keyring grub2-efi-x64 grub2-efi-x64-modules grub2-tools grub2-tools-efi grub2-tools-extra

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
