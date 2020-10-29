# rpi-pxe-flasher

Raspberry Pi 4 image flasher using PXE.

## How to use
```
# docker run --privileged --net host --rm -it -e PXE_INTF=eth1 -e PXE_SUBNET=10.101.101.100,10.101.101.150 yaamai/rpi-pxe-flasher:latest
```
