#!/bin/sh
set -e

. ./common.sh

file="$1"
mnt="$2"
new=0

msg "Selecting disk image $file"

mounted=$(mount | grep -c loop0p1) || mounted=0
if [ "$mounted" != "0" ]; then
	msg2 "Cleaning up previous build"
	./unmount.sh
fi

if [ ! -e "$file" ]; then
	msg2 "Preparing disk image file"
	fallocate -l 1.2G "$file"
	printf "o\nn\np\n1\n\n\na\nw\n" | fdisk "$file" > /dev/null
	new=1
fi

msg2 "Setting up disk mountpoint"
sudo losetup -f --show "$file"
sudo kpartx -a /dev/loop0

if [ "$new" = "1" ]; then
	msg2 "Formatting disk"
	sudo mkfs.ext4 /dev/mapper/loop0p1
fi

msg2 "Mounting image"
sudo mount /dev/mapper/loop0p1 "$mnt"
