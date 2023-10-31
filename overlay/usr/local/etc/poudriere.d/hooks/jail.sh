#!/bin/sh

event="${1}"

case "${event}" in
mount)
	mntpath="${2}"

	mkdir -p "${mntpath}/host/lib" "${mntpath}/host/usr/lib" "${mntpath}/host/usr/local/lib"
	mount -r -t nullfs /lib "${mntpath}/host/lib"
	mount -r -t nullfs /usr/lib "${mntpath}/host/usr/lib"
	mount -r -t nullfs /usr/local/lib "${mntpath}/host/usr/local/lib"
	;;
*)
	;;
esac
