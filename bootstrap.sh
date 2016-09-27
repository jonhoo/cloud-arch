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
sudo pacman -Syy
{
	# prefer linux-lts over linux:
	# https://bbs.archlinux.org/viewtopic.php?pid=1358205#p1358205
	pacman -Sqg base | sed 's/^\(linux\)$/\1-lts/';
	echo \
		syslinux \
		openssh sudo \
		gnu-netcat rsync wget git \
		python2 \
		vim \
		linux-lts \
		cloud-init dmidecode \
		rxvt-unicode-terminfo
} | sudo pacstrap -c "$tmp" -

# Okay, so, the Arch cloud-init package is currently horribly broken in that
# it's missing *a lot* of dependencies. We'll install those here for now.
# See https://git.launchpad.net/cloud-init/tree/requirements.txt
sudo pacman --root "$tmp" -S --noconfirm \
	python2-jinja \
	python2-prettytable \
	python2-oauthlib \
	python2-configobj \
	python2-yaml \
	python2-requests \
	python2-jsonpatch \
	python2-six

# this dependency is only in the aur
aur_install_to "$tmp" python2-argparse

./unmount.sh "$tmp"
mv bootstrapped.raw.tmp bootstrapped.raw
