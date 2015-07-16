#!/bin/bash

sec() {
	printf "\n\e[1;34m:: \e[0m\e[1m%s\e[0m\n" "$*"
}
msg() {
	printf "\e[1;32m==> \e[39m%s\e[0m\n" "$*"
}
warn() {
	printf "\e[1;33m==> %s\e[0m\n" "$*"
}
err() {
	printf "\e[1;31m==> %s\e[0m\n" "$*"
}
msg2() {
	printf "\e[1;32m -> \e[39m%s\e[0m\n" "$*"
}
warn2() {
	printf "\e[1;33m -> %s\e[0m\n" "$*"
}
err2() {
	printf "\e[1;31m -> %s\e[0m\n" "$*"
}

IMAGE_FILE="$1"

# Location on host system where VM image is mounted;
# this is root for the VM being built.
MNT_POINT="$2"

pre_setup() {
	local size="$1"
	local self=$(basename "$0")
	self="${self%.sh}"
	sec "Constructing image for model '$self'"

	if [ $# -eq 1 ]; then
		msg "Growing image $IMAGE_FILE"
		./unmount.sh
		fallocate -l "$size" "$IMAGE_FILE"
		./mount.sh "$IMAGE_FILE" "$MNT_POINT"

		msg "Growing partitions"
		local lodev=$(cat .mountpoint)
		sudo arch-chroot "$MNT_POINT" /usr/bin/growpart "/dev/${lodev}" 1

		msg "Growing filesystem"
		./unmount.sh

		lodev=$(basename "$(sudo losetup -f --show "$IMAGE_FILE")")
		e2fsck -f "/dev/${lodev}p1"
		resize2fs "/dev/${lodev}p1"
		sudo losetup -d "/dev/${lodev}"

		msg "Remounting"
		./mount.sh "$IMAGE_FILE" "$MNT_POINT"
	fi

	msg "Preparing model install"
}
