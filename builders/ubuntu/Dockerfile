FROM ubuntu:noble
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y git kmod mkosi dpkg-dev devscripts systemd-ukify systemd-boot cpio mtools && apt clean && rm -rf /var/lib/apt/lists

# for building rocky images, on ubuntu, lol
RUN apt-get update && apt-get install -y xfsprogs && apt clean && rm -rf /var/lib/apt/lists

WORKDIR /cache/packages
WORKDIR /out
WORKDIR /work

RUN echo -n 'system mkosi version: ' && mkosi --version

# Install mkosi from source -- the version in the Ubuntu repos is too old
WORKDIR /mkosi-src
RUN git clone "https://github.com/systemd/mkosi"
RUN cd mkosi && git checkout "3f321bd79b55c75f6e5701dfef4404d715bd764f" # Specific master revision proven to work
RUN ln -s /mkosi-src/mkosi/bin/mkosi /usr/local/bin/mkosi
RUN echo -n 'local mkosi version: ' && /usr/local/bin/mkosi --version

VOLUME /cache/packages
VOLUME /out
VOLUME /work

# Important!
WORKDIR /work
