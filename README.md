# rpi-pxe-flasher

Raspberry Pi 4 image flasher using PXE.

## Requirements
1. PXE configured rpi4
2. Isolated network(L2) (directly connected or vlan)

## How to use
```
# docker run --privileged --net host --rm -it -e PXE_INTF=eth1 -e PXE_SUBNET=10.101.101.100,10.101.101.150 yaamai/rpi-pxe-flasher:latest
# ubuntu/flash_ubuntu20.sh root@10.101.101.xxx
```

## Todo
1. fully automated image flash (using dnsmasq's hook script)
2. configurable network addresses via env
3. auto interface configuration (up/down, assign address)
4. add pxe config procedure
5. add vlan config script (gs308e)
