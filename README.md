# rpi-pxe-flasher

Raspberry Pi 4 image flasher using PXE.

## Requirements
1. PXE configured rpi4
2. Isolated network(L2) (directly connected or vlan)

## How to use
```
# docker run --privileged --net host --rm -it -e PXE_INTF=eth1 yaamai/rpi-pxe-flasher:latest
# ubuntu/flash_ubuntu20.sh root@10.101.101.xxx
```

## Todo
1. add pxe config procedure
2. add vlan config script (gs308e)
