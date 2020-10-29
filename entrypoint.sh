#!/usr/bin/env bash
set -e
set -x

cleanup() {
  ip addr del dev $interface $server_ip/$server_prefix_len || true
  ip link set dev $interface down || true
}

main() {
  local interface=${PXE_INTF:-enp3s0}
  local server_ip=${PXE_IP:-10.101.101.1}
  local server_prefix_len=${PXE_IP_LEN:-24}
  local server_url=${PXE_URL:-http://$server_ip:8000}
  local subnet=${PXE_SUBNET:-10.101.101.100,10.101.101.150}

  trap cleanup EXIT

  ip addr add dev $interface $server_ip/$server_prefix_len || true
  ip link set dev $interface up || true

  echo "ip=dhcp modules=loop,dhcp,network alpine_repo=$server_url/alpine apkovl=$server_url/alpine/overlay.tar.gz" > $PWD/tftpboot/alpine/cmdline.txt

  dnsmasq \
    -d \
    -R \
    -z \
    -i $interface \
    -F $subnet \
    --dhcp-script /hook-dhcp.sh \
    --enable-tftp \
    --tftp-root=$PWD/tftpboot/alpine \
    --pxe-service=0,"Raspberry Pi Boot" &

  cd $PWD/http && python3 -m http.server &

  wait -n
}

main
