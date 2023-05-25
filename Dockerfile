FROM alpine:3.18.0 AS builder

ARG ALPINE_URL=https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/aarch64/alpine-rpi-3.18.0-aarch64.tar.gz
ENV ALPINE_TAR=/work/alpine.tar.gz

# download alpien release tar
RUN apk add --update curl &&\
    mkdir /work &&\
    cd /work &&\
    curl -Lo alpine.tar.gz ${ALPINE_URL}
WORKDIR /work

# Generate pxe-bootable initramfs
RUN apk add --update squashfs-tools &&\
    mkdir -p initramfs/modloop-rpi4 &&\
    cd initramfs &&\
    tar xf ../alpine.tar.gz ./boot/modloop-rpi4 ./boot/initramfs-rpi4 &&\
    unsquashfs -d modloop-rpi4/lib boot/modloop-rpi4  'modules/*/modules.*' 'modules/*/kernel/net/packet/af_packet.ko' &&\
    (cd modloop-rpi4 && find . | cpio -H newc -ov | gzip) > initramfs-ext-rpi4 &&\
    cat boot/initramfs-rpi4 initramfs-ext-rpi4 > initramfs-rpi4-netboot

# Generate ssh config overlay
COPY overlay /work/overlay
RUN cd overlay &&\
    tar zcf overlay.tar.gz etc/

# Generate tftpboot dir
RUN mkdir -p tftpboot/alpine &&\
    cd tftpboot/alpine &&\
    tar xf ${ALPINE_TAR} &&\
    rm -rf apks &&\
    cp /work/initramfs/initramfs-rpi4-netboot boot/initramfs-rpi4

# Generate http dir
RUN mkdir -p http/alpine &&\
    tar xf ${ALPINE_TAR} ./apks  &&\
    mv apks/* http/alpine &&\
    cp /work/overlay/overlay.tar.gz http/alpine/overlay.tar.gz


FROM alpine:3.18.0
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--", "/entrypoint.sh"]

WORKDIR /pxe
RUN mkdir -p /pxe /pxe/tftpboot /pxe/http &&\
    apk add --update dnsmasq python3 bash openssh-client
COPY --from=builder /work/tftpboot /pxe/tftpboot
COPY --from=builder /work/http /pxe/http
COPY entrypoint.sh hook-dhcp.sh /
