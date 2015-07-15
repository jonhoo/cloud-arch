archlinux.current.raw: bootstrapped.raw build.sh
	./build.sh

config.iso: user-data meta-data
	pacman -Qi cdrkit >/dev/null || sudo pacman -S cdrkit # for genisoimage
	genisoimage  -output $@ -volid cidata -joliet -rock user-data meta-data

bootstrapped.raw: bootstrap.sh
	./bootstrap.sh

archlinux.raw: archlinux.current.raw config.iso
	# depends on config.iso because some settings aren't applied unless the
	# image is clean
	cp $< $@

%-image.raw: setups/%.sh archlinux.current.raw
	cp archlinux.current.raw $@.tmp
	sh -c 'set -e; D=$$(mktemp -d -t arch-cloud-setup.XXXXXXXXXX); ./mount.sh "$@.tmp" "$$D"; setups/$*.sh "$@.tmp" "$$D"; ./unmount.sh "$$D"'
	mv $@.tmp $@

.PRECIOUS: %-image.raw

mount: archlinux.raw
	mkdir -p mnt
	./mount.sh $< ./mnt

unmount:
	./unmount.sh

FWD=hostfwd=tcp::10080-:80
run-%: config.iso %-image.raw
	qemu-system-x86_64 \
		-enable-kvm \
		-nographic -drive file=$*-image.raw,if=virtio \
		-drive file=config.iso,if=virtio \
		-net user,hostfwd=tcp::10022-:22,$(FWD) \
		-net nic

run: config.iso archlinux.raw
	qemu-system-x86_64 \
		-enable-kvm \
		-nographic -drive file=archlinux.raw,if=virtio \
		-drive file=config.iso,if=virtio \
		-net user,hostfwd=tcp::10022-:22 -net nic

clean:
	rm -f bootstrapped.raw
	rm -f archlinux.current.raw
	rm -f archlinux.raw
	rm -f config.iso
