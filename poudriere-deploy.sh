#!/bin/sh
#
# Copyright (c) 2023 Konrad Witaszczyk
#
# This software was developed by the University of Cambridge Department of
# Computer Science and Technology with support from Innovate UK project 105694,
# "Digital Security by Design (DSbD) Technology Platform Prototype".
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

#
# This script requires the pkg-sign host to be defined in ssh_config(5) that
# executes a remote command to sign a repository or a package after successfully
# connecting to a signing server, e.g.
#
# Host pkg-sign
#     Hostname pkg-signing-server
#     User pkg-signing-user
#     RemoteCommand sh ~/poudriere-infrastructure/poudriere-key.sh sign
#

die() {
	echo "${*}" >&2
	exit 1
}

usage() {
	echo "usage: ${0} [-nDV] repo-path remote-path"
	exit 1

}

main() {
	local _repo_path _remote_path _rsync_flags _verbose

	_rsync_flags="-avz"
	_verbose=0

	while getopts "DnV" _arg; do
		case "${_arg}" in
		n)
			_rsync_flags="${_rsync_flags} -n"
			;;
		D)
			_rsync_flags="${_rsync_flags} --delete"
			;;
		V)
			_verbose=1
			;;
		*)
			usage
			;;
		esac
	done
	shift $((${OPTIND} - 1))

	if [ "${_verbose}" -eq 1 ]; then
		set -x
	fi

	_repo_path="${1}"
	_remote_path="${2}"

	[ -d "${_repo_path}" ] || usage
	[ -n "${_remote_path}" ] || usage

	pkg repo "${_repo_path}" signing_command: ssh pkg-sign
	if [ $? -ne 0 ]; then
		die "Unable to create a repository."
	fi

	sha256 -q "${_repo_path}/Latest/pkg.pkg" |
	    ssh pkg-sign >"${_repo_path}/Latest/pkg.pkg.sig"
	if [ $? -ne 0 ]; then
		die "Unable to sign pkg."
	fi

	rsync ${_rsync_flags} "${_repo_path}" "${_remote_path}"
	if [ $? -ne 0 ]; then
		die "Unable to upload packages."
	fi
}

main "${@}"
