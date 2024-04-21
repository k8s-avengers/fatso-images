FROM fedora:40

# A customization entrypoint, so users can easily inject their proxies / ca-certificates / etc.
# @TODO this might end up picking up something meant for an Ubuntu builder
WORKDIR /extra-dockerfile
ADD early-init.docker.sh /extra-dockerfile/early-init.docker.sh
RUN bash -e /extra-dockerfile/early-init.docker.sh

RUN dnf -y install --best --allowerasing systemd-ukify systemd-boot systemd-boot-unsigned cpio mtools xfsprogs git kmod mkosi apt dpkg ubu-keyring grub2-efi-x64 grub2-efi-x64-modules grub2-tools grub2-tools-efi grub2-tools-extra

WORKDIR /cache/packages
WORKDIR /out
WORKDIR /work

RUN echo -n 'system mkosi version: ' && mkosi --version

# Install mkosi from source -- the version in the Ubuntu repos is too old
WORKDIR /mkosi-src
RUN git clone "https://github.com/systemd/mkosi" && cd mkosi && git checkout "59c28dd3895bfdda40752423b312a3878ee4543d" # Specific master revision proven to work 
RUN ln -s /mkosi-src/mkosi/bin/mkosi /usr/local/bin/mkosi
RUN echo -n 'local mkosi version: ' && /usr/local/bin/mkosi --version

VOLUME /cache/packages
VOLUME /out
VOLUME /work

# Important!
WORKDIR /work
