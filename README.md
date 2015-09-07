# cloud-arch

This repository contains scripts for building (and customizing) an Arch
VM image. The resulting image is set up with
[`cloud-init`](https://cloudinit.readthedocs.org/), and should be easily
deployable to cloud VM hosts like OpenStack. The images can also be run
locally using QEMU for testing.

The Arch Wiki has [a
page](https://wiki.archlinux.org/index.php/OpenStack#Creating_images_yourself)
describing how to create an OpenStack image of Arch, but there are still
a few details that need to be ironed out that are not clear from the
list there. Experimental builds using
[image-bootstrap](https://github.com/hartwork/image-bootstrap) are
available from [linuximages.de](http://linuximages.de/openstack/arch/),
and those are probably the ones you should be using if you don't need a
customized image.

This collection of scripts performs the bare minimum of effort needed to
get Arch up and running with a network connection, with an ssh server,
and with `cloud-init` configurations applied. While `image-bootstrap` is
likely more feature-complete, it is harder to read and use if you want
to generate your own custom image from scratch.

To build an image, run `make`. It will produce `archlinux.current.raw`,
which is a RAW disk file containing your VM image. If you want to boot
the image with QEMU, run `make run`. `cloud-init` options can be set in
`user-data`.

There are two primary build scripts: `bootstrap.sh` and `build.sh`. The
former creates the disk and file system, and installs all packages. The
latter modifies the default configuration options, enables services for
start at boot, etc. This split was introduced so that the configuration
can be iterated on quickly without having to re-install all the packages
every time.

The default username/password for SSH access (on `localhost:10022`) is
arch/arch. Add your SSH public key in `user-data` for keyless access.
**The key that is currently there is mine, and should be removed unless
you want me to have access to your server.** You should also change the
password, or disable password authentication altogether, if you're
making this box publicly available.

## Building and running a simple web image

```shell
# Get the source
git clone https://github.com/jonhoo/cloud-arch
cd cloud-arch

# Create a new VM setup that installs and enables apache
cp setups/example.sh setups/web.sh
echo 'rooted pacman -S --noconfirm apache' >> setups/web.sh
echo 'rooted systemctl enable httpd' >> setups/web.sh

# Build image
make web.img

# If you modify the scripts, only necessary files will be rebuilt
make web.img # is up to date

# Run VM using qemu (in the background)
screen -d -m make run-web

# Wait for VM to boot
sleep 4

# Check that apache is running
curl localhost:10080/

# SSH access is enabled -- the password is 'arch' by default.
# See the user-data file to change this and to add keys.
ssh -p 10022 arch@localhost sudo poweroff
```

## Hacks

In order to get everything working correctly, the scripts do some things
that you wouldn't expect to be necessary. These are:

 - Builds `cloud-utils` from bzr source. Can't use `cloud-utils` in AUR
   because upstream has not yet produced a release with the fix for
   [1197894](https://bugzilla.redhat.com/show_bug.cgi?id=1197894).
   `image-bootstrap` just downloads the `growpart` binary (which is all
   we really need from the package), but I figured it would be nice to
   keep the full package.
 - Bootstrap installs `dmidecode` because many VM hosts use this to
   query information about the guest.
 - `build.sh` enables serial console output for the bootloader so that
   the non-GUI logs work correctly. It also disables the fancy syslinux
   boot menu for the same reason.
 - `build.sh` makes a bunch of modifications to `/etc/cloud/cloud.cfg`
   since the defaults are all for Ubuntu, and not Arch. Of particular
   importance is the fact that the default group list is changed, since
   the upstream list contains several groups that do not exist on Arch,
   and will thus cause `useradd` to fail when users are later created.
 - All data source types are enabled by default.
 - Since Arch doesn't have syslog, we avoid `cloud-init` trying to use
   it (bug
   [1172983](https://bugs.launchpad.net/cloud-init/+bug/1172983)).
 - A number of other Ubunut-specific modules are disabled --- in
   particular, anything related to apt, upstart, or grub.
 - The network is set up to use DHCP on all interfaces starting with
   `e`. This is because some cloud providers use `eth0`, whereas others
   leave the choice to the OS, which might choose something like `ens3`.
   `systemd-resolved` is also enabled to handle the DNS configuration.
 - `/etc/machine-id` and `/var/lib/dbus/machine-id` are wiped so that
   different machines running the same image will get different IDs.
 - A warning is printed to `/etc/motd` that `pacman-key` will have to be
   initialized after first boot. It is unfortunate that this can't be
   automated in a straightforward way; it would require writing a
   systemd service file, and injecting a binary whose sole purpose is to
   run two commands once. Sysadmins using the image should instead add
   the `pacman-key` init commands to `scripts-per-once`.
