archlinux.raw: bootstrapped.raw build.sh
	./build.sh

config.iso: user-data meta-data
	pacman -Qi cdrkit >/dev/null || sudo pacman -S cdrkit # for genisoimage
	genisoimage  -output $@ -volid cidata -joliet -rock user-data meta-data

bootstrapped.raw: bootstrap.sh
	./bootstrap.sh

%.instance.raw: %.raw config.iso
	# depends on config.iso because some settings aren't applied unless the
	# image is clean
	cp $*.raw $@

%-image.raw: setups/%.sh archlinux.raw
	cp archlinux.raw $@.tmp
	sh -c 'set -e; D=$$(mktemp -d -t arch-cloud-setup.XXXXXXXXXX); ./mount.sh "$@.tmp" "$$D"; setups/$*.sh "$@.tmp" "$$D"; ./unmount.sh "$$D"'
	mv $@.tmp $@

.PRECIOUS: %-image.raw
.PRECIOUS: %.instance.raw

mount: archlinux.instance.raw
	mkdir -p mnt
	./mount.sh $< ./mnt

unmount:
	./unmount.sh

FWD=hostfwd=tcp::10080-:80
run-%: config.iso %-image.instance.raw
	qemu-system-x86_64 \
		-enable-kvm \
		-nographic -drive file=$*-image.instance.raw,if=virtio \
		-drive file=config.iso,if=virtio \
		-net user,hostfwd=tcp::10022-:22,$(FWD) \
		-net nic

run: config.iso archlinux.instance.raw
	qemu-system-x86_64 \
		-enable-kvm \
		-nographic -drive file=archlinux.instance.raw,if=virtio \
		-drive file=config.iso,if=virtio \
		-net user,hostfwd=tcp::10022-:22 -net nic

clean:
	rm -f bootstrapped.raw
	rm -f *.instance.raw
	rm -f archlinux.raw
	rm -f *-image.raw
	rm -f *.raw.tmp
	rm -f config.iso
