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

PORT_BASEURL="https://github.com/CTSRD-CHERI/cheribsd-ports/tree/main"
TMPFILE=""

cleanup() {
	if [ -f "${TMPFILE}" ]; then
		rm "${TMPFILE}"
	fi
}

die() {
	echo "${*}" >&2
	cleanup
	exit 1
}

usage() {
	echo "usage: ${0} repo-path"
	cleanup
	exit 1
}

main() {
	local _date _repo_name _repo_path
	local _comment _origin _port _version _www

	_repo_path="${1}"
	[ -d "${_repo_path}" ] || usage

	_repo_name=$(basename "${_repo_path}")
	_repo_path="$(dirname "${_repo_path}")/${_repo_name}"
	_date=$(date)

	if [ ! -f "${_repo_path}/packagesite.pkg" ]; then
		die "File '${_repo_path}/packagesite.pkg' doesn't exist."
	fi

	TMPFILE=$(mktemp -t poudriere-packagesite)

	cat <<EOF >"${TMPFILE}"
<!DOCTYPE html>
<html>
  <head>
    <title>CheriBSD packages: ${_repo_name}</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  </head>
  <body>
    <h1>CheriBSD packages: ${_repo_name}</h1>

    <p>
      Last updated: ${_date}.
    </p>

    <table>
      <tr>
        <th>Name</th>
	<th>Version</th>
	<th>Website</th>
	<th>CheriBSD port</th>
	<th>Description</th>
      </tr>
EOF
	tar Oxf "${_repo_path}/packagesite.pkg" packagesite.yaml |
	    jq -j '.name, "\t", .origin, "\t", .version, "\t", .www, "\t", .comment, "\n"' |
	    sort |
	    while read _name _origin _version _www _comment; do
		_port="${PORT_BASEURL}/${_origin}"
		cat <<EOF >>"${TMPFILE}"
      <tr>
        <td>${_name}</td>
        <td>${_version}</td>
        <td><a href="${_www}">website</a></td>
        <td><a href="${_port}">port</a></td>
        <td>${_comment}</td>
      </tr>
EOF
	done
	cat <<EOF >>"${TMPFILE}"
    </table>
  </body>
</html>
EOF

	chgrp ctsrd "${TMPFILE}"
	chmod 0755 "${TMPFILE}"
	mv "${TMPFILE}" "${_repo_path}.html"
	if [ $? -ne 0 ]; then
		die "Unable to move '${TMPFILE}' to '${_repo_path}.html'."
	fi
}

main "${@}"
