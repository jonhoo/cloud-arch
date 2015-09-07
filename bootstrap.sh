#!/bin/sh
set -e

. ./common.sh

sudo date > /dev/null

sec "Creating bootstrap image"

msg "Checking that we have necessary build tools"
pacman -Qi arch-install-scripts >/dev/null || sudo pacman -S arch-install-scripts # for pacstrap

tmp=$(mktemp -d -t arch-cloud-bootstrap.XXXXXXXXXX)
tmp=$(readlink -f "$tmp")
rm -f bootstrapped.raw.tmp
rm -f bootstrapped.raw
./mount.sh "bootstrapped.raw.tmp" "$tmp"

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

msg "Installing cloud-utils"
aur_install_to "$tmp" cloud-utils-bzr

./unmount.sh "$tmp"
mv bootstrapped.raw.tmp bootstrapped.raw
