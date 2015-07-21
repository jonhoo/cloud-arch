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
		rooted /usr/bin/growpart "/dev/${lodev}" 1

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

# aur_install_to root pkg [AUR dependencies...]
#
# aur_install_to installs a package from the AUR using pacaur, which builds a
# package on the host and then installs it inside $root. All AUR dependencies
# must be specified, since dependencies not in this list already installed on
# the host will not be installed.
#
# Non-AUR dependencies can be left off, since the final pacman -U install will
# take care of them.
aur_install_to() {
	mntpoint="$1"
	shift

	msg2 "Checking that we have necessary build tools"
	pacman -Qi arch-install-scripts >/dev/null || sudo pacman -S arch-install-scripts # for pacstrap
	pacman -Qi pacaur >/dev/null || yaourt -S pacaur

	msg2 "Building $@"
	# we do this locally so we don't have to pull in all of base-devel inside the VM
	local bd=$(mktemp -d -t build_cloud-utils.XXXXXXXXXX)
	bd=$(readlink -f "$bd")
	local pwd=$(pwd)
	cd "$bd"

	msg2 "Building with pacaur"
	# specifying AUR dependencies explicitly in case they're already installed on
	# the host
	env "BUILDDIR=$bd" pacaur --noconfirm --noedit --rebuild -f -m "$@"
	find . -type f -name '*.pkg.tar.xz' -exec sudo cp {} "$mntpoint" \;
	cd "$pwd"
	rm -rf "$bd"

	msg "Installing $@"
	sudo arch-chroot "$mntpoint" find / -maxdepth 1 -type f -name '*.pkg.tar.xz' | xargs sudo arch-chroot "$mntpoint" pacman --noconfirm -U
	sudo arch-chroot "$mntpoint" find / -maxdepth 1 -type f -name '*.pkg.tar.xz' -exec rm {} \;
}
