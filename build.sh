#!/bin/sh
set -e

. ./common.sh

sudo date > /dev/null

sec "Configuring disk image for the cloud"

msg "Checking that we have Arch's install scripts"
pacman -Qi arch-install-scripts >/dev/null || sudo pacman -S arch-install-scripts # for genfstab and arch-chroot

cp bootstrapped.raw archlinux.raw.tmp
tmp=$(mktemp -d -t arch-cloud-build.XXXXXXXXXX)
tmp=$(readlink -f "$tmp")
./mount.sh "archlinux.raw.tmp" "$tmp"

if [ ! -e ".mountpoint" ]; then
	exit 1
fi
lodev=$(cat .mountpoint)

msg "Generating /etc/fstab for $tmp"
uuid=$(sudo blkid -o value "/dev/mapper/${lodev}p1" | head -n1)
sudo genfstab -U "$tmp/" | sudo tee -a "$tmp/etc/fstab" > /dev/null
sudo sed -i "s@$tmp@/@" "$tmp/etc/fstab"

msg "Setting up bootloader"
sudo mkdir -p "$tmp/boot/syslinux"
sudo cp -r "$tmp/usr/lib/syslinux/bios"/*.c32 "$tmp/boot/syslinux/"
sudo extlinux --install "$tmp/boot/syslinux"
sudo sed -i "1i \\SERIAL 0 115200" "$tmp/boot/syslinux/syslinux.cfg"
sudo sed -i "s@DEFAULT arch@DEFAULT archfallback@" "$tmp/boot/syslinux/syslinux.cfg"
sudo sed -i "s@TIMEOUT 50@TIMEOUT 5@" "$tmp/boot/syslinux/syslinux.cfg"
sudo sed -i "s@PROMPT 0@PROMPT 1@" "$tmp/boot/syslinux/syslinux.cfg"
sudo sed -i "s@^UI @# UI @" "$tmp/boot/syslinux/syslinux.cfg"
sudo sed -i "s@root=/dev/sda3@root=UUID=$uuid console=tty0 console=ttyS0,115200n8@" "$tmp/boot/syslinux/syslinux.cfg"

msg2 "Writing MBR"
sudo dd conv=notrunc bs=440 count=1 "if=$tmp/usr/lib/syslinux/bios/mbr.bin" "of=/dev/${lodev}"

msg "Enabling [multilib]"
sudo sed -i '/#\[multilib\]/,+1s/^#//' "$tmp/etc/pacman.conf"
sudo arch-chroot "$tmp" pacman -Sy

msg "Configuring cloud-init"

# Set up main user
msg2 "Configuring default user"
sudo sed -i "s@distro: ubuntu@distro: arch@" "$tmp/etc/cloud/cloud.cfg"
sudo sed -i "s@name: ubuntu@name: arch@" "$tmp/etc/cloud/cloud.cfg"
sudo sed -i "s@gecos: Ubuntu@gecos: Arch@" "$tmp/etc/cloud/cloud.cfg"
sudo sed -i "s@groups: .*@groups: [adm, wheel]@" "$tmp/etc/cloud/cloud.cfg"
sudo sed -i "/sudo:/d" "$tmp/etc/cloud/cloud.cfg"
sudo sed -i '/# %wheel ALL=(ALL) NOPASSWD: ALL/s/^# //' "$tmp/etc/sudoers"

# Set up data sources
msg2 "Setting up data sources"
sudo sed -i "/Example datasource config/i \\datasource_list: [ NoCloud, ConfigDrive, OpenNebula, Azure, AltCloud, OVF, MAAS, GCE, OpenStack, CloudSigma, Ec2, CloudStack, None ]" "$tmp/etc/cloud/cloud.cfg"

# Avoid errors about syslog not existing
# See https://bugs.launchpad.net/cloud-init/+bug/1172983
msg2 "Fixing syslog permissions"
sudo sed -i "/datasource_list/i \\syslog_fix_perms: null" "$tmp/etc/cloud/cloud.cfg"

# Don't start Ubuntu things
msg2 "Disabling unused modules"
sudo sed -i '/emit_upstart/d' "$tmp/etc/cloud/cloud.cfg"
sudo sed -i '/ubuntu-init-switch/d' "$tmp/etc/cloud/cloud.cfg"
sudo sed -i '/grub-dpkg/d' "$tmp/etc/cloud/cloud.cfg"
sudo sed -i '/apt-pipelining/d' "$tmp/etc/cloud/cloud.cfg"
sudo sed -i '/apt-configure/d' "$tmp/etc/cloud/cloud.cfg"
sudo sed -i '/byobu/d' "$tmp/etc/cloud/cloud.cfg"

# Set up network
msg "Configuring network"
echo '[Match]
Name=e*

[Network]
DHCP=ipv4

[DHCPv4]
UseHostname=false' | sudo tee "$tmp/etc/systemd/network/dhcp-all.network"
sudo arch-chroot "$tmp" systemctl enable systemd-networkd.service
sudo arch-chroot "$tmp" systemctl enable systemd-resolved.service
sudo ln -sfn /run/systemd/resolve/resolv.conf "$tmp/etc/resolv.conf"
sudo sed -i 's/network.target/network-online.target/' "$tmp/usr/lib/systemd/system/cloud-init.service"

# Start daemons on boot
msg "Enabling system services"
sudo arch-chroot "$tmp" systemctl enable sshd
sudo arch-chroot "$tmp" systemctl enable cloud-init
sudo arch-chroot "$tmp" systemctl enable cloud-config
sudo arch-chroot "$tmp" systemctl enable cloud-final

# Remove machine ID so it is regenerated on boot
msg "Wiping machine ID"
printf "" | sudo tee "$tmp/etc/machine-id"
printf "" | sudo tee "$tmp/var/lib/dbus/machine-id"

msg "Writing motd"
# We don't want to use the pacman keys in the image, because the private
# component is effectively public (anyone with the image can find out what it
# is). Unfortunately, there is no easy way to run the necessary commands on
# (only) the next boot as far as I'm aware. Instead, we put it in the motd so
# that any user will see it the first time they log into the machine.
# For future reference, the private key can be checked with
#
#   sudo gpg --homedir /etc/pacman.d/gnupg -K
#
echo "Welcome to your brand new Arch cloud instance!

Before doing anything else, you should re-key pacman with

 # pacman-key --init
 # pacman-key --populate archlinux

You might also want to update the system using

 # pacman -Syu

(you can change this message by editing /etc/motd)" | sudo tee -a "$tmp/etc/motd"

./unmount.sh "$tmp"
mv archlinux.raw.tmp archlinux.raw
