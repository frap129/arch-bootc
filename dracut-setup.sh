#!/usr/bin/env bash
set -xeo pipefail

args=('--force')

for line in $(find /usr/lib/modules -name pkgbase); do
	read -r pkgbase <"${line}"
	kver="${line#'/usr/lib/modules/'}"
	kver="${kver%'/pkgbase'}"

	dracut "${args[@]}" "/${line%'/pkgbase'}/initramfs.img" --kver "$kver"
done
