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

pre_setup() {
	self=$(basename "$0")
	self="${self%.sh}"
	sec "Constructing image for model '$self'"

	if [ $# -eq 3 ]; then
		msg "Growing image $1"
		./unmount.sh
		fallocate -l "$3" "$1"
		./mount.sh "$1" "$2"

		msg "Growing partitions"
		lodev=$(cat .mountpoint)
		sudo arch-chroot "$2" /usr/bin/growpart "/dev/${lodev}" 1

		msg "Remounting"
		./unmount.sh
		./mount.sh "$1" "$2"
	fi

	msg "Preparing model install"
}
