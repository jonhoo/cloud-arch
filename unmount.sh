#!/bin/sh
set -e

. ./common.sh

msg "Unmounting disk image"
sudo umount /dev/mapper/loop0p1
sudo kpartx -d /dev/loop0
sudo losetup -d /dev/loop0
rm -rf "$1"
