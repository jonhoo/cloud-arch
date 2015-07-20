#!/bin/sh

# This file will build example-image.raw when running `make example-image.raw`.

. ./common.sh
pre_setup # pass an argument to increase the image size (e.g. 2G)

# The root filesystem of the image is mounted at "$MNT_POINT".
root="$2"

# Make any modifications you wish and they will be saved in the image.
# You should prefix commands with `rooted` to modify the install.
rooted touch /example-build
