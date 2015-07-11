#!/bin/sh
set -e

. ./common.sh

msg "Unmounting disk image"
sudo umount /dev/mapper/loop0p1
sudo kpartx -d /dev/loop0
sudo losetup -d /dev/loop0

if [ $# -eq 1 ] ; then
	msg2 "Removing tempdir $1"
	rmdir "$1"
fi
