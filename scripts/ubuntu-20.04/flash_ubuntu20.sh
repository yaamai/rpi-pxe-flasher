#!/bin/bash


main() {
  local target=$1
  local dev=/dev/sda

  flash_image $target $dev

  ensure_firmware_source
  mount_flashed_devices $target $dev
  tweak_ubuntu20_usbboot $target
  fix_cgroup_for_k3s $target

  umount_devices $target $dev
  modify_partition $target $dev
}

flash_image() {
  local target=$1
  local dev=$2

  ssh $target '
    wget http://10.101.101.1:8000/ubuntu-20.04.1-preinstalled-server-arm64+raspi.img.xz -O - |
    xz -d |
    dd bs=1M of='$dev'
    sync; sync; sync
    mdev -s
  '
}

modify_partition() {
  local target=$1
  local dev=$2

  # resize root(2) part. to 32G
  # and create empty third part.
  ssh $target '
    wget http://10.101.101.1:8000/aarch64/e2fsprogs-extra-1.45.6-r0.apk
    apk add --force-non-repository --allow-untrusted e2fsprogs-extra-1.45.6-r0.apk
    e2fsck -f -p /dev/sda2
    resize2fs /dev/sda2 32G
    (
      echo d
      echo 2
      echo n
      echo p
      echo 2
      echo 526336
      echo +32G
      echo n
      echo p
      echo 3
      echo 67635200
      echo
      echo w
    ) | fdisk '$dev'
    mdev -s
  '
}

umount_devices() {
  local target=$1
  local dev=$2
  ssh $target '
    umount /mnt/boot
    umount /mnt
    sync; sync; sync
  '
}

fix_cgroup_for_k3s() {
  local target=$1
  ssh $target '
    if ! grep cgroup_memory /mnt/boot/cmdline.txt; then
      sed "1s:$: cgroup_memory=1 cgroup_enable=memory:" -i /mnt/boot/cmdline.txt
    fi
  '
}

mount_flashed_devices() {
  local target=$1
  local dev=$2

  ssh $target '
    mountpoint /mnt || mount '${dev}'2 /mnt/
    mountpoint /mnt/boot || mount '${dev}'1 /mnt/boot/
  '
}

ensure_firmware_source() {
  if [[ ! -e firmware ]]; then
    git clone --depth 1 --filter=blob:none --no-checkout https://github.com/raspberrypi/firmware.git
    pushd firmware
      git checkout master -- "boot/*.dat" "boot/*.elf"
    popd
  fi
}

tweak_ubuntu20_usbboot() {
  local target=$1

  scp -r auto_decompress_kernel firmware/boot/{*.dat,*.elf} $target:/mnt/boot/
  scp -r 999_decompress_rpi_kernel $target:/mnt/etc/apt/apt.conf.d/
  ssh $target 'zcat /mnt/boot/vmlinuz > /mnt/boot/vmlinux'
  ssh $target '
    if [[ ! -e /mnt/boot/config.txt.org ]]; then
      cp /mnt/boot/config.txt /mnt/boot/config.txt.org
    fi
    cp /mnt/boot/config.txt.org /mnt/boot/config.txt
  '
  ssh $target "sed -e '/\[pi4]/,/\[/{//!d}' -e '/\[pi4]/a max_framebuffers=2\nboot_delay\nkernel=vmlinux\ninitramfs initrd.img followkernel\n' -i /mnt/boot/config.txt"
  ssh $target 'chmod +x /mnt/boot/auto_decompress_kernel /mnt/etc/apt/apt.conf.d/999_decompress_rpi_kernel'
}

tweak_ubuntu20_multipathd_longhorn() {
  local target=$1
  ssh $target '
    sed -e "/blacklist/,/}/d" -i /mnt/etc/multipath.conf
    echo -e "blacklist {\n    devnode \"^sd[a-z0-9]+\"\n}" >> /mnt/etc/multipath.conf
  '
}

main "$@"
