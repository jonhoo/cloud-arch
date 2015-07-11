#!/bin/sh
set -e

. ./common.sh

sudo date > /dev/null

sec "Creating bootstrap image"

msg "Checking that we have Arch's install scripts"
pacman -Qi arch-install-scripts >/dev/null || sudo pacman -S arch-install-scripts # for pacstrap

tmp=$(mktemp -d -t tmp.XXXXXXXXXX)
tmp=$(readlink -f "$tmp")
rm -f bootstrapped.raw
./mount.sh "bootstrapped.raw" "$tmp"

msg "Installing packages"
sudo pacstrap -c "$tmp" base \
	syslinux \
	openssh sudo \
	gnu-netcat rsync wget git \
	python2 \
	vim \
	cloud-init dmidecode
	#gdb htop lsof strace mlocate numactl tmux the_silver_searcher \
	#base-devel clang cmake linux-headers \
	#git mercurial subversion bzr \
	#gnuplot graphviz \
	#ghc go rust python2 ruby \
	#pkgfile \
	#zsh fish \
	#rxvt-unicode-terminfo \
	#emacs (draws in gtk3!) \

./unmount.sh "$tmp"
