#!/usr/bin/env bash
set -e

echo "ip=dhcp modules=loop,dhcp,network alpine_repo=http://10.101.101.1:8000 apkovl=http://10.101.101.1:8000/overlay.tar.gz" > $PWD/tftpboot/cmdline.txt

dnsmasq \
  -d \
  -R \
  -z \
  -i ${PXE_INTF} \
  -F ${PXE_SUBNET} \
  --enable-tftp \
  --tftp-root=$PWD/tftpboot \
  --pxe-service=0,"Raspberry Pi Boot" &

cd $PWD/http && python3 -m http.server &

wait -n
