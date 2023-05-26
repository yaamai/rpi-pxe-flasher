#!/bin/ash

main() {
  local dev="/dev/sda"
  local crypt_root_name="cryptroot"
  local crypt_password="password"
  local mnt_to="/mnt"
  local material_server="http://10.101.101.1:8000/user/scripts/ubuntu-22.04-luks"
  local fs_tar_url="${material_server}/ubuntu-22.04.2-preinstalled-server-arm64%2Braspi.tar.gz"
  local ssh_pubkey_url="${material_server}/id_rsa.pub"
  local pkgs_url="${material_server}/pkgs/list.txt"
  local pkgs_base_url="${material_server}/pkgs"

  modify_partition_table ${dev}
  prepare_partitions ${dev} ${crypt_root_name} ${mnt_to} ${crypt_password}
  flash_ubuntu_with_tar ${fs_tar_url} ${mnt_to}
  prepare_luks_config ${dev} ${crypt_root_name} ${mnt_to} ${ssh_pubkey_url}
  generate_luks_initramfs ${mnt_to} ${pkgs_url} ${pkgs_base_url}
  umount_devices ${mnt_to}
}

modify_partition_table() {
  local dev=$1

  # ${dev}1 => /boot/firmware 512MB vfat
  # ${dev}2 => / ALL ext4
  (
    echo o
    echo n
    echo p
    echo 1
    echo 2048
    echo +512m
    echo t
    echo c
    echo a
    echo 1
    echo n
    echo p
    echo 2
    echo 1050624
    echo ""
    echo p
  ) | fdisk ${dev}

}

prepare_partitions() {
  local dev=$1
  local crypt_root_name=$2
  local mnt_to=$3
  local pass=$4

  local firmware_dev=${dev}1
  local root_dev=${dev}2
  local root_crypt_dev=/dev/mapper/${crypt_root_name}

  echo -n "${pass}" | cryptsetup luksFormat --cipher aes-xts-plain64 --key-size 256 --hash sha256 --use-random ${root_dev} -
  echo -n "${pass}" | cryptsetup open ${root_dev} ${crypt_root_name}

  mkfs.vfat ${firmware_dev}
  mkfs.ext4 ${root_crypt_dev}

  # WA for old ubuntu fsck
  tune2fs -O "^orphan_file,^metadata_csum_seed" ${root_crypt_dev}

  mount ${root_crypt_dev} ${mnt_to}
  mkdir -p ${mnt_to}/boot/firmware
  mount ${firmware_dev} ${mnt_to}/boot/firmware
}

flash_ubuntu_with_tar() {
  local url=$1
  local mnt_to=$2
  wget -q "${url}" -O - | tar xzf - -C ${mnt_to} --strip 1
}

prepare_luks_config() {
  local dev=$1
  local crypt_root_name=$2
  local mnt_to=$3
  local ssh_pubkey_url=$4

  local root_crypt_dev=/dev/mapper/${crypt_root_name}
  local root_uuid=$(blkid ${dev}2 | awk -F\" '{print $2}')
  local firmware_uuid=$(blkid ${dev}1 | awk -F\" '{print $2}')
  local ssh_pubkey=$(wget -q "${ssh_pubkey_url}" -O -)

  echo "${crypt_root_name} UUID=${root_uuid} none luks,discard" > ${mnt_to}/etc/crypttab

  mkdir ${mnt_to}/etc/dropbear/initramfs -p
  echo "${ssh_pubkey}" > ${mnt_to}/etc/dropbear/initramfs/authorized_keys

  local cmdline=${mnt_to}/boot/firmware/cmdline.txt
  sed -E 's;cryptdevice=[^ ]+;;g' -i ${cmdline}
  sed -E 's;rootdelay=[^ ]+;;g' -i ${cmdline}
  sed -E 's;^;cryptdevice=/dev/disk/by-uuid/'${root_uuid}':cryptroot ;' -i ${cmdline}
  sed -E 's;^;rootdelay=10 ;' -i ${cmdline}
  sed -E 's;root=[^ ]+;root='${root_crypt_dev}';' -i ${cmdline}
  sed -E 's;\s?splash\s?;;' -i ${cmdline}

  echo "${root_crypt_dev} / ext4 discard,errors=remount-ro 0 1" >> ${mnt_to}/etc/fstab
  echo "UUID=${firmware_uuid} /boot/firmware vfat defaults 0 1" >> ${mnt_to}/etc/fstab
}

generate_luks_initramfs() {
  local mnt_to=$1
  local pkgs_url=$2
  local pkgs_base_url=$3

  local pkgs=$(wget -q "${pkgs_url}" -O -)

  mount -t proc none ${mnt_to}/proc
  mount -t sysfs none ${mnt_to}/sys
  mount -o bind /dev ${mnt_to}/dev
  mount -o bind /dev/pts ${mnt_to}/dev/pts
  mount -o bind /run ${mnt_to}/run

  cd ${mnt_to}
  for p in ${pkgs}; do
      wget -q "${pkgs_base_url}/${p}"
  done
  chroot ${mnt_to} dpkg -i *.deb
  rm ${mnt_to}/*.deb

  cp ${mnt_to}/boot/initrd.img-* ${mnt_to}/boot/firmware/initrd.img
  cp ${mnt_to}/boot/vmlinuz-* ${mnt_to}/boot/firmware/vmlinuz

  umount ${mnt_to}/proc
  umount ${mnt_to}/sys
  umount ${mnt_to}/dev
  umount ${mnt_to}/dev/pts
  umount ${mnt_to}/run
}

umount_devices() {
  local mnt_to=$1
  umount ${mnt_to}/boot/firmware
  umount ${mnt_to}
  sync; sync; sync
}

main
