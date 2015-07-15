#!/bin/sh
set -e

. ./common.sh

file="$1"
mnt="$2"
new=0

msg "Selecting disk image $file"

if [ -e .mountfile ]; then
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
lodev=$(basename "$(sudo losetup -f --show "$file")")
sudo kpartx -a "/dev/$lodev"
echo "$lodev" > .mountpoint

if [ "$new" = "1" ]; then
	msg2 "Formatting disk"
	sudo mkfs.ext4 "/dev/mapper/${lodev}p1"
fi

if [ $# -eq 2 ]; then
	msg2 "Mounting image"
	sudo mount "/dev/mapper/${lodev}p1" "$mnt"
fi
