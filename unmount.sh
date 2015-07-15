#!/bin/sh
set -e

. ./common.sh

if [ ! -e ".mountpoint" ]; then
	exit 1
fi

lodev=$(cat .mountpoint)
msg "Unmounting disk image"
sudo umount "/dev/mapper/${lodev}p1" || :
sudo kpartx -d "/dev/${lodev}" || :
sudo losetup -d "/dev/${lodev}"
rm .mountpoint

if [ $# -eq 1 ] ; then
	msg2 "Removing tempdir $1"
	rmdir "$1"
fi
