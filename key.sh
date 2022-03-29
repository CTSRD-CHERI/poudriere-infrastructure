#!/bin/sh
#
# Copyright (c) 2022 Konrad Witaszczyk
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory under DARPA/AFRL contract (FA8750-10-C-0237)
# ("CTSRD"), as part of the DARPA CRASH research programme.
#
# This software was developed by SRI International and the University of
# Cambridge Computer Laboratory (Department of Computer Science and
# Technology) under DARPA contract HR0011-18-C-0016 ("ECATS"), as part of the
# DARPA SSITH research programme.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

KEY_PREFIX="pkg.cheribsd.org"
KEY_DIR="${HOME}/keys/pkg.cheribsd.org"
KEY_LATEST="${KEY_DIR}/${KEY_PREFIX}.latest"
KEY_PRIVATE="${KEY_DIR}/${KEY_PREFIX}.latest.priv"
KEY_PUBLIC="${KEY_DIR}/${KEY_PREFIX}.latest.pub"

die() {
	echo "${*}" >&2
	exit 1
}

usage() {
	echo "usage: key.sh generate|sign"
}

key_generate() {
	local _date _keydir _keyname _keypath

	_date="$(date "+%Y%m%d")"
	if [ $? -ne 0 ]; then
		die "Unable to calculate a date."
	fi

	_keyname="${KEY_PREFIX}.${_date}"
	_keydir="${KEY_DIR}/${_keyname}"
	_keypath="${_keydir}/${_keyname}"

	if [ -d "${_keydir}" ]; then
		die "Directory ${_keydir} already exists. Remove it and try again."
	fi

	mkdir -p "${_keydir}"
	if [ $? -ne 0 ]; then
		die "Unable to create a key directory."
	fi

	openssl genrsa -out "${_keypath}.priv" 2048
	if [ $? -ne 0 ]; then
		die "Unable to generate a key."
	fi

	chmod 0400 "${_keypath}.priv"
	if [ $? -ne 0 ]; then
		die "Unable to change permissions."
	fi

	openssl rsa -in "${_keypath}.priv" -out "${_keypath}.pub" -pubout
	if [ $? -ne 0 ]; then
		die "Unable to generate a public key."
	fi

	_fingerprint="$(sha256 -q "${_keypath}.pub")"
	if [ $? -ne 0 ]; then
		die "Unable to calculate a fingerprint."
	fi

	cat << EOF >"${_keypath}"
function: "sha256"
fingerprint: "${_fingerprint}"
EOF
	if [ $? -ne 0 ]; then
		die "Unable to store a fingerprint."
	fi

	ln -sf "${_keyname}/${_keyname}" "${KEY_LATEST}"
	if [ $? -ne 0 ]; then
		die "Unable to create a symlink to the latest key."
	fi
	ln -sf "${_keyname}/${_keyname}.pub" "${KEY_PUBLIC}"
	if [ $? -ne 0 ]; then
		die "Unable to create a symlink to the latest public key."
	fi
	ln -sf "${_keyname}/${_keyname}.priv" "${KEY_PRIVATE}"
	if [ $? -ne 0 ]; then
		die "Unable to create a symlink to the latest private key."
	fi

	echo
	echo "You can find the new key in: ${_keydir}."
	echo
	echo "Remember to add ${_keypath} to share/keys/pkg/trusted/ in CheriBSD."
}

key_sign() {
	local _checksum _cert _signature

	read -t 2 _checksum
	if [ -z "${_checksum}" ]; then
		die "Checksum cannot be empty."
	fi

	_signature=$(echo -n "${_checksum}" |
	    openssl dgst -sign "${KEY_PRIVATE}" -sha256 -binary)
	if [ $? -ne 0 ]; then
		die "Unable to generate a signature."
	fi

	_cert=$(cat "${KEY_PUBLIC}")
	if [ $? -ne 0 ]; then
		die "Unable to read the latest public key."
	fi

	cat << EOF
SIGNATURE
${_signature}
CERT
${_cert}
END
EOF
}

main() {
	local _cmd

	_cmd="${1}"

	case "${_cmd}" in
	generate)
		key_generate
		;;
	sign)
		key_sign
		;;
	*)
		usage
		;;
	esac
}

main "${@}"
