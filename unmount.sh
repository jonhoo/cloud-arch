#!/bin/sh
set -e

. ./common.sh

msg "Unmounting disk image"
sudo umount /dev/mapper/loop0p1
sudo kpartx -d /dev/loop0
sudo losetup -d /dev/loop0

if [ $# -eq 1 ] ; then
	rm -rf "$1"
fi
