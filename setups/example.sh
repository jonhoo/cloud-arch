#!/bin/sh

# This file will build example-image.raw when running `make example-image.raw`.

. ./common.sh
pre_setup "$1" "$2" # pass a third option to increase the image size (e.g. 2G)

# The root filesystem of the image is mounted at "$2".
root="$2"

# Make any modifications you wish and they will be saved in the image.
# You should use `sudo arch-chroot "$root"` to modify the install.
sudo arch-chroot "$root" touch /example-build
