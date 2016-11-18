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

# rooted cmd args...
#
# Runs "cmd args..." chroot'd into the VM (at $MNT_POINT) as root.
rooted() {
	sudo arch-chroot "$MNT_POINT" "$@"
}

# vm_install packages
#
# Runs pacman -S --noconfirm rooted inside the VM
vm_install() {
	sudo pacman --root "$MNT_POINT" -S --noconfirm "$@"
}

pre_setup() {
	local size="$1"
	local self=$(basename "$0")
	self="${self%.sh}"
	sec "Constructing image for model '$self'"

	if [ $# -eq 1 ]; then
		msg "Growing image $IMAGE_FILE"
		./unmount.sh
		fallocate -l "$size" "$IMAGE_FILE"
		local lodev=$(basename "$(sudo losetup -f --show "$IMAGE_FILE")")

		msg "Growing partition"
		# easiest way of growing a partition is to re-create it
		sudo partx -a "/dev/${lodev}"
		sudo partx -d "/dev/${lodev}"
		printf "o\nn\np\n1\n\n\na\nw\n" | sudo fdisk "/dev/${lodev}" > /dev/null || true
		sudo partx -a "/dev/${lodev}"

		msg "Growing filesystem"
		sudo e2fsck -f "/dev/${lodev}p1"
		sudo resize2fs "/dev/${lodev}p1"
		sudo losetup -d "/dev/${lodev}"

		msg "Remounting"
		./mount.sh "$IMAGE_FILE" "$MNT_POINT"

		# we just wiped the MBR, so we need to write syslinux again
		sudo dd conv=notrunc bs=440 count=1 "if=$MNT_POINT/usr/lib/syslinux/bios/mbr.bin" "of=/dev/${lodev}"
	fi

	msg "Preparing model install"
}

# aur_install_to root pkg
#
# aur_install_to installs a package from the AUR using pacaur, which builds a
# package on the host and then installs it inside $root.
aur_install_to() {
	mntpoint="$1"
	shift

	msg2 "Checking that we have necessary build tools"
	pacman -Qi pacaur >/dev/null || yaourt -S pacaur

	# we build on the host so we don't have to pull in all of base-devel inside the VM
	msg2 "Building $*"
	local bd=$(mktemp -d -t aur_build.XXXXXXXXXX)
	bd=$(readlink -f "$bd")

	env "PKGDEST=$bd" pacaur --noconfirm --noedit --rebuild --foreign -m "$@"

	# it would be great if pacaur had a --root option (issue #338) so we
	# could avoid the separate build and install steps, but it seems that's
	# not something that will be added to pacaur:
	# https://github.com/rmarquis/pacaur/issues/338#issuecomment-134566092
	msg2 "Installing"
	find "$bd" -type f -name '*.pkg.tar.xz' | xargs sudo pacman --root "$mntpoint" --noconfirm -U

	msg2 "Cleaning"
	rm -rf "$bd"
}
