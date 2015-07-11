config.iso: user-data meta-data
	genisoimage  -output $@ -volid cidata -joliet -rock user-data meta-data

bootstrapped.raw: bootstrap.sh
	./bootstrap.sh

archlinux.current.raw: bootstrapped.raw build.sh
	./build.sh

archlinux.raw: archlinux.current.raw config.iso
	# depends on config.iso because some settings aren't applied unless the
	# image is clean
	cp $< $@

mount: archlinux.raw
	mkdir mnt
	./mount.sh $< ./mnt

unmount:
	./unmount.sh

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
