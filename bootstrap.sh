#!/bin/sh
set -e

. ./common.sh

sudo date > /dev/null

sec "Creating bootstrap image"

msg "Checking that we have necessary build tools"
pacman -Qi arch-install-scripts >/dev/null || sudo pacman -S arch-install-scripts # for pacstrap
pacman -Qi pacaur >/dev/null || yaourt -S pacaur

tmp=$(mktemp -d -t arch-cloud-bootstrap.XXXXXXXXXX)
tmp=$(readlink -f "$tmp")
rm -f bootstrapped.raw
./mount.sh "bootstrapped.raw" "$tmp"

msg "Building cloud-utils"
# we do this locally so we don't have to pull in all of base-devel inside the VM
bd=$(mktemp -d -t build_cloud-utils.XXXXXXXXXX)
bd=$(readlink -f "$bd")
pwd=$(pwd)
cd "$bd"
msg2 "Building with pacaur"
# specifying AUR dependencies explicitly in case they're already installed on
# the host
env "BUILDDIR=$bd" pacaur --noconfirm --noedit --rebuild -f -m cloud-utils-bzr euca2ools python2-requestbuilder
find . -type f -name '*.pkg.tar.xz' -exec sudo cp {} "$tmp" \;
cd "$pwd"
rm -rf "$bd"

msg "Installing packages"
sudo pacstrap -c "$tmp" base \
	syslinux \
	openssh sudo \
	gnu-netcat rsync wget git \
	python2 \
	vim \
	cloud-init dmidecode \
	rxvt-unicode-terminfo
	#gdb htop lsof strace mlocate numactl tmux the_silver_searcher \
	#base-devel clang cmake linux-headers \
	#git mercurial subversion bzr \
	#gnuplot graphviz \
	#ghc go rust python2 ruby \
	#pkgfile \
	#zsh fish \
	#emacs (draws in gtk3!) \

msg "Install cloud-utils"
sudo arch-chroot "$tmp" find / -maxdepth 1 -type f -name '*.pkg.tar.xz' | xargs sudo arch-chroot "$tmp" pacman --noconfirm -U
sudo arch-chroot "$tmp" find / -maxdepth 1 -type f -name '*.pkg.tar.xz' -exec rm {} \;

./unmount.sh "$tmp"
