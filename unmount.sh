#!/bin/sh
set -e

. ./common.sh

if [ ! -e ".mountpoint" ]; then
	exit 1
fi

lodev=$(cat .mountpoint)
msg "Unmounting disk image"
at=$(mount | grep "/dev/mapper/${lodev}p1" | awk '{print $3}')
if [ -n "$at" ]; then
	sudo umount "$at/proc" 2>/dev/null || :
	sudo umount "$at/tmp" 2>/dev/null || :
	sudo umount "$at/dev" 2>/dev/null || :
	sudo umount "$at/sys" 2>/dev/null || :
	sudo umount "/dev/mapper/${lodev}p1" 2>/dev/null || :
fi
sudo kpartx -d "/dev/${lodev}" || :
sudo losetup -d "/dev/${lodev}"
rm .mountpoint

if [ $# -eq 1 ] ; then
	msg2 "Removing tempdir $1"
	rmdir "$1"
fi
