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

die() {
	echo "${*}" >&2
	exit 1
}

usage() {
	echo "usage: ${0} repo-path json-url"
	exit 1
}

main() {
	local _json_path _repo_path
	local _makefile_path _origin _prefix

	_repo_path="${1}"
	[ -d "${_repo_path}" ] || usage
	_json_path="${2}"
	[ -f "${_json_path}" ] || usage

	jq -r '.ports.failed[] | .origin' "${_json_path}" |
	    while read _origin; do
		if [ ! -f "${_repo_path}/${_origin}/Makefile" ]; then
			die "Invalid origin: ${_origin}."
		fi
		_makefile_path="${_repo_path}/${_origin}/Makefile.purecap"
		if [ -f "${_makefile_path}" ]; then
			grep -q "^BROKEN_purecap_failed=" "${_makefile_path}"
			if [ $? -eq 0 ]; then
				# The port is already marked as failed.
				continue
			fi
			_prefix="\n"
		else
			_prefix=""
		fi
		printf "${_prefix}BROKEN_purecap_failed=1\n" >>"${_makefile_path}"
		if [ $? -ne 0 ]; then
			die "Unable to update ${_makefile_path}."
		fi
	done
}

main "${@}"
