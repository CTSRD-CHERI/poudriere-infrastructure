#!/bin/sh

SYSROOT_MORELLO_HYBRID="/zdata/cheri/output/morello-sdk/sysroot-morello-hybrid"

event="${1}"

case "${event}" in
mount)
	mntpath="${2}"

	# Mount directories with host libraries.
	mkdir -p "${mntpath}/host/lib" "${mntpath}/host/usr/lib" "${mntpath}/host/usr/local/lib"
	mount -r -t nullfs /lib "${mntpath}/host/lib"
	mount -r -t nullfs /usr/lib "${mntpath}/host/usr/lib"
	mount -r -t nullfs /usr/local/lib "${mntpath}/host/usr/local/lib"

	if [ -d "${SYSROOT_MORELLO_HYBRID}" ]; then
		# Mount a sysroot to cross-compile hybrid ABI ports that
		# actually use capabilities.
		#
		# The sysroot doesn't have to exist when building CheriABI or
		# benchmark ABI packages, in which case simply do nothing.
		mkdir -p "${mntpath}/toolchain/sysroot-morello-hybrid"
		mount -r -t nullfs "${SYSROOT_MORELLO_HYBRID}" \
		    "${mntpath}/toolchain/sysroot-morello-hybrid"
	fi
	;;
start)
	# Create a hints file with the host libraries.
	chroot "${MASTERMNT}" /sbin/ldconfig -f /var/run/ld-elf-host.so.hints /host/lib /host/usr/lib /host/usr/local/lib
	;;
*)
	;;
esac
