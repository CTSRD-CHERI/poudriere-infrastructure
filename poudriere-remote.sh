#!/bin/sh
#
# Copyright (c) 2022 Konrad Witaszczyk
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

# WARNING: This script is intended for use with a remote host dedicated to build
# packages. It requires root access via sudo on the host, might break the host
# and loose its data.
#
# Before you use this script, you must create the remote host and configure it:
# 1. Configure sshd with SSH key authentication.
# 2. Create a user and add it to the wheel group.
# 3. Add your SSH key to the user.
# 4. Allow the user to execute any command as root without a password using
# sudo.
# 5. Optionally, create a separate disk for a ZFS zpool.

# Dependencies to install on a remote host.
REMOTE_DEPS="
aarch64-binutils
autoconf
automake
bash
cmake
git
glib
gmake
gsed
libtool
nginx
ninja
pixman
pkgconf
poudriere
python3
texinfo
"

# Remote zpool.
REMOTE_ZPOOL="zdata"

# Remote paths.
REMOTE_PATH_ZDATA="/${REMOTE_ZPOOL}"
REMOTE_PATH_CHERI="${REMOTE_PATH_ZDATA}/cheri"
REMOTE_PATH_OUTPUT="${REMOTE_PATH_CHERI}/output"
REMOTE_PATH_DISTFILES="${REMOTE_PATH_ZDATA}/distfiles"
REMOTE_PATH_POUDRIERE="${REMOTE_PATH_ZDATA}/poudriere"
REMOTE_PATH_REPOS="${REMOTE_PATH_ZDATA}/repos"
REMOTE_PATH_CHERIBUILD="${REMOTE_PATH_REPOS}/cheribuild"
REMOTE_PATH_CHERIBSD="${REMOTE_PATH_REPOS}/cheribsd"
REMOTE_PATH_POUDRIEREINFRASTRUCTURE="${REMOTE_PATH_REPOS}/poudriere-infrastructure"
REMOTE_PATH_OVERLAY="${REMOTE_PATH_POUDRIEREINFRASTRUCTURE}/overlay"
REMOTE_PATH_ROOTFS_AARCH64="${REMOTE_PATH_OUTPUT}/rootfs-aarch64"
REMOTE_PATH_ROOTFS_MORELLO_HYBRID="${REMOTE_PATH_OUTPUT}/rootfs-morello-hybrid"
REMOTE_PATH_ROOTFS_MORELLO_PURECAP="${REMOTE_PATH_OUTPUT}/rootfs-morello-purecap"
REMOTE_PATH_ROOTFS_RISCV64_PURECAP="${REMOTE_PATH_OUTPUT}/rootfs-riscv64-purecap"

# Remote poudriere-infrastructure configuration.
REMOTE_POUDRIEREINFRASTRUCTURE_REPO="https://github.com/CTSRD-CHERI/poudriere-infrastructure.git"
REMOTE_POUDRIEREINFRASTRUCTURE_BRANCH="master"

# Remote cheribuild configuration.
REMOTE_CHERIBUILD_REPO="https://github.com/CTSRD-CHERI/cheribuild.git"
REMOTE_CHERIBUILD_BRANCH="qemu-cheri-bsd-user"

# Remote cheribsd configuration.
REMOTE_CHERIBSD_REPO="https://github.com/CTSRD-CHERI/cheribsd.git"
REMOTE_CHERIBSD_BRANCH="dev"

# Remote cheribsd-ports configuration.
REMOTE_CHERIBSDPORTS_REPO="https://github.com/CTSRD-CHERI/cheribsd-ports.git"
REMOTE_CHERIBSDPORTS_BRANCH="main"

# Remote jail configuration.
REMOTE_JAIL_VERSION="14.0-CURRENT"

# Global dynamic variables.
REMOTE_DISK=""
REMOTE_DRYRUN=0
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_VERBOSE=0

info() {
	echo "[ INFO] ${*}"
}

debug() {
	if [ "${REMOTE_VERBOSE}" -lt 1 ]; then
		return;
	fi
	echo "[DEBUG] ${*}"
}

error() {
	echo "${*}" >&2
}

die() {
	error "[ERROR] ${@}"
	exit 1
}

usage() {
cat << EOF >&2
Usage: ${0} build [-nv] [-d disk] [-b [user@]host:dest] -h host -t target -a
       ${0} build [-nv] [-d disk] [-b [user@]host:dest] -h host -t target -f file [-f file2 ...]
       ${0} build [-nv] [-d disk] [-b [user@]host:dest] -h host -t target origin [origin2 ...]

Parameters:
    -h host             -- Host to build packages on (ssh(1) destination).
    -t target           -- Target to build packages for (cheribuild OS target).

Mutually exclusive parameters:
    -a                  -- Build the whole ports tree.
    -f file             -- Build ports listed in file.
    origin              -- Build a port matching origin.

Options:
    -b [user@]host:dest -- Backup built packages to a host (rsync(1) destination).
    -d disk             -- Use disk to create a ZFS zpool for data.
    -n                  -- Print commands instead of executing them.
                           Results depend on already executed commands without -n.
    -v                  -- Enable verbose output.
                           Use twice to print shell commands.
EOF
	exit 1
}

check() {
	if [ "${REMOTE_DRYRUN}" -ne 0 ]; then
		info "Dry-run: ${@}"
	else
		"${@}"
		if [ $? -ne 0 ]; then
			die "Failed to execute command '${*}'."
		fi
	fi
}

sshcmd() {
	ssh "${REMOTE_HOST}" "${@}"
}

cheribuildcmd() {
	"${REMOTE_PATH_CHERIBUILD}/cheribuild.py" \
	    --quiet --source-root "${REMOTE_PATH_CHERI}" \
	    "${@}"
}

gitclonecmd() {
	local _branch _name _path _repo

	_name="${1}"
	_repo="${2}"
	_branch="${3}"
	_path="${4}"

	[ -n "${_name}" ] || die "Missing _name."
	[ -n "${_repo}" ] || die "Missing _repo."
	[ -n "${_branch}" ] || die "Missing _branch."
	[ -n "${_path}" ] || die "Missing _path."

	if sshcmd ls -d "${_path}/.git" >/dev/null 2>&1; then
		info "Updating previously cloned ${_name} in ${_path}."
		check sshcmd git -C "${_path}" pull -fq
	else
		info "Cloning ${_name} into ${_path}."
		check sshcmd git clone -q --single-branch \
		    --branch "${_branch}" "${_repo}" "${_path}"
	fi
}

dircreate() {
	local _dir _filesystem

	_dir="${1}"

	[ -n "${_dir}" ] || die "Missing _dir."

	if [ -n "${REMOTE_DISK}" ]; then
		_filesystem="${_dir#/}"
		if sshcmd zfs list -H -t filesystem -o name \
		    "${_filesystem}" >/dev/null 2>&1; then
			debug "Using a previously created filesystem ${_filesystem}."
		else
			check sshcmd sudo zfs create "${_filesystem}"
		fi
	else
		if sshcmd ls -d "${_dir}" >/dev/null 2>&1; then
			debug "Using a previously created directory ${_dir}."
		else
			info "Creating a directory with a path ${_dir}."
			check sshcmd sudo mkdir "${_dir}"
		fi
	fi

	check sshcmd sudo chown "${REMOTE_USER}" "${_dir}"
}

init() {
	if [ -n "${REMOTE_DISK}" ]; then
		if sshcmd sudo zpool list -H "${REMOTE_ZPOOL}" >/dev/null 2>&1; then
			debug "Using a previously created zpool ${REMOTE_ZPOOL}."
		else
			info "Creating a zpool with a name ${REMOTE_ZPOOL}."
			check sshcmd sudo zpool create "${REMOTE_ZPOOL}" \
			    "${REMOTE_DISK}"
		fi
	else
		dircreate "${REMOTE_PATH_ZDATA}"
	fi

	dircreate "${REMOTE_PATH_DISTFILES}"
	dircreate "${REMOTE_PATH_CHERI}"
	dircreate "${REMOTE_PATH_REPOS}"
	dircreate "${REMOTE_PATH_CHERIBSD}"
	dircreate "${REMOTE_PATH_POUDRIEREINFRASTRUCTURE}"
	dircreate "${REMOTE_PATH_POUDRIERE}"

	if sshcmd sudo pkg query %o = devel/git >/dev/null; then
		debug "Using previously installed devel/git."
	else
		info "Installing devel/git."
		check sshcmd sudo pkg install -qy devel/git
	fi

	gitclonecmd "poudriere-infrastructure" \
	    "${REMOTE_POUDRIEREINFRASTRUCTURE_REPO}" \
	    "${REMOTE_POUDRIEREINFRASTRUCTURE_BRANCH}" \
	    "${REMOTE_PATH_POUDRIEREINFRASTRUCTURE}"
	gitclonecmd "cheribuild" \
	    "${REMOTE_CHERIBUILD_REPO}" \
	    "${REMOTE_CHERIBUILD_BRANCH}" \
	    "${REMOTE_PATH_CHERIBUILD}"
	gitclonecmd "cheribsd" \
	    "${REMOTE_CHERIBSD_REPO}" \
	    "${REMOTE_CHERIBSD_BRANCH}" \
	    "${REMOTE_PATH_CHERIBSD}"
}

init_local() {
	local _cheribuildflags _cheribuildtarget _cheribuildstatus _file _files
	local _host_machine_arch _machine _machine_arch _rootfs _target

	_target="${1}"

	[ -n "${_target}" ] || die "Missing _target."

	case "${_target}" in
	cheribsd-aarch64)
		_machine="arm64"
		_machine_arch="aarch64"
		_rootfs="${REMOTE_PATH_ROOTFS_AARCH64}"
		_cheribuildflags="--morello-qemu/no-use-smbd"
		_cheribuildtarget="sdk-aarch64"
		;;
	cheribsd-morello-hybrid)
		_machine="arm64"
		_machine_arch="aarch64"
		# Use an aarch64 world to build hybrid packages.
		#
		# We'd like to build natively most of the packages. The packages
		# that we must build for the hybrid ABI can be built against
		# an aarch64 world.
		_rootfs="${REMOTE_PATH_ROOTFS_AARCH64}"
		_cheribuildflags="--morello-qemu/no-use-smbd"
		_cheribuildtarget="sdk-morello-hybrid"
		;;
	cheribsd-morello-purecap)
		_machine="arm64"
		_machine_arch="aarch64c"
		_rootfs="${REMOTE_PATH_ROOTFS_MORELLO_PURECAP}"
		_cheribuildflags="--morello-qemu/no-use-smbd"
		_cheribuildtarget="sdk-morello-purecap"
		;;
	cheribsd-riscv64)
		_machine="riscv64"
		_machine_arch="riscv64"
		_rootfs="${REMOTE_PATH_ROOTFS_RISCV64}"
		_cheribuildflags=""
		_cheribuildtarget="sdk-riscv64"
		;;
	cheribsd-riscv64-purecap)
		_machine="riscv64"
		_machine_arch="riscv64c"
		_rootfs="${REMOTE_PATH_ROOTFS_RISCV64_PURECAP}"
		_cheribuildflags=""
		_cheribuildtarget="sdk-riscv64-purecap"
		;;
	*)
		die "Unexpected target ${_target}."
	esac
	_cheribuildflags="${_cheribuildflags} \
	    --clean \
	    --no-skip-sdk \
	    --qemu/no-use-smbd \
	    --${_target}/source-directory ${REMOTE_PATH_CHERIBSD}"
	_cheribuildstatus="${REMOTE_PATH_OUTPUT}/.${_cheribuildtarget}.done"

	_host_machine_arch=$(check sudo uname -p)
	if [ $? -ne 0 ]; then
		die "Unable to get a host machine architecture."
	fi

	info "Updating dependency packages."
	check sudo pkg install -qy ${REMOTE_DEPS}

	if [ "${_host_machine_arch}" != "${_machine_arch}" ]; then
		info "Rebuilding bsd-user-qemu."
		check cheribuildcmd bsd-user-qemu
	fi

	info "Copying configuration files."
	_files=$(cd "${REMOTE_PATH_OVERLAY}" &&
	    find etc/ usr/ -type f -o -type l)
	if [ $? -ne 0 ] || [ -z "${_files}" ]; then
		die "Unable to list files in ${REMOTE_PATH_POUDRIERE}."
	fi
	for _file in ${_files}; do
		check sudo mkdir -p "$(dirname "/${_file}")"
		check sudo rm -f "/${_file}"
		check sudo cp -a "${REMOTE_PATH_OVERLAY}/${_file}" "/${_file}"
	done

	if [ "${_host_machine_arch}" != "${_machine_arch}" ]; then
		info "Reconfiguring binary image activators."
		check sudo service qemu_user_static restart
	fi

	info "Restarting nginx."
	check sudo service nginx restart

	sudo poudriere ports -l -n | grep "^${REMOTE_CHERIBSDPORTS_BRANCH}$"
	if [ $? -eq 0 ]; then
		debug "Using a previously created ports tree with a name ${REMOTE_CHERIBSDPORTS_BRANCH}."
	else
		info "Creating a ports tree with a name ${REMOTE_CHERIBSDPORTS_BRANCH}."
		check sudo poudriere ports -c -m git \
		    -p "${REMOTE_CHERIBSDPORTS_BRANCH}" \
		    -U "${REMOTE_CHERIBSDPORTS_REPO}" \
		    -B "${REMOTE_CHERIBSDPORTS_BRANCH}"
	fi

	if [ -f "${_cheribuildstatus}" ]; then
		debug "Using previously built SDK for the target ${_target}."
	else
		info "Building SDK for the target ${_target}."
		if [ -d "${_rootfs}" ]; then
			# Set the owner of rootfs to an unprivileged user in
			# case we must update any already existing files (e.g.,
			# when rootfs was partially created due to a bug that is
			# fixed now).
			#
			# cheribuild creates files as the uprivileged user but
			# we later change their owner to root:wheel as required
			# by the base system.
			check sudo chown -R "${REMOTE_USER}:wheel" "${_rootfs}"
		fi
		check cheribuildcmd ${_cheribuildflags} "${_cheribuildtarget}"
		check touch "${_cheribuildstatus}"
	fi

	info "Copying jail files."
	_files=$(cd "${REMOTE_PATH_OVERLAY}" &&
	    find zdata/ -type f -o -type l)
	if [ $? -ne 0 ] || [ -z "${_files}" ]; then
		die "Unable to list files in ${REMOTE_PATH_POUDRIERE}."
	fi
	for _file in ${_files}; do
		check sudo mkdir -p "$(dirname "/${_file}")"
		check sudo rm -f "/${_file}"
		check sudo cp -a "${REMOTE_PATH_OVERLAY}/${_file}" "/${_file}"
	done

	if [ "${_host_machine_arch}" != "${_machine_arch}" ]; then
		if [ -f "${_rootfs}/libexec/ld-${_machine_arch}.so.1" ]; then
			debug "Using previously copied guest ld-${_machine_arch}.so.1."
		else
			info "Copying guest ld-elf.so.1 to ld-${_machine_arch}.so.1."
			check mv "${_rootfs}/libexec/ld-elf.so.1" \
			    "${_rootfs}/libexec/ld-${_machine_arch}.so.1"
		fi
		if [ -f "${_rootfs}/libexec/ld-elf.so.1" ]; then
			debug "Using previously copied host ld-elf.so.1."
		else
			info "Copying host ld-elf.so.1."
			check cp /libexec/ld-elf.so.1 "${_rootfs}/libexec/ld-elf.so.1"
		fi
	fi

	# When running natively or emulated, CheriBSD base system requires base
	# system files to be owned by root:wheel.
	check sudo chown -R root:wheel "${_rootfs}"

	sudo poudriere jail -i -j "${_target}" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		debug "Using a previously created jail with a name ${_target}."
	else
		info "Creating a jail with a name ${_target}."
		check sudo poudriere jail -c -j "${_target}" \
		    -v "${REMOTE_JAIL_VERSION}" \
		    -a "${_machine}.${_machine_arch}" \
		    -m null \
		    -M "${_rootfs}"
	fi

	if [ -f "${REMOTE_PATH_PACKAGES}/${_target}/Latest/pkg.pkg" ]; then
		debug "Using a previously built package manager for the jail."
	else
		info "Building a package manager to test the jail."
		check sudo poudriere bulk -j "${_target}" \
		    -p "${REMOTE_CHERIBSDPORTS_BRANCH}" \
		    ports-mgmt/pkg
	fi
}

build_options() {
	local _arg _origin

	_all=0
	_backup=""
	_disk=""
	_dryrun=0
	_files=""
	_host=""
	_target=""
	_verbose=0

	while getopts "ab:d:f:h:nt:v" _arg; do
		case "${_arg}" in
		a)
			_all=1
			;;
		b)
			[ -z "${_backup}" ] || usage
			_backup="${OPTARG}"
			;;
		d)
			_disk="${OPTARG}"
			;;
		f)
			_files="${_files} -f '${OPTARG}'"
			;;
		h)
			[ -z "${_host}" ] || usage
			_host="${OPTARG}"
			;;
		n)
			_dryrun=1
			;;
		t)
			[ -z "${_target}" ] || usage
			_target="${OPTARG}"
			;;
		v)
			_verbose=$((_verbose + 1))
			;;
		*)
			usage
			;;
		esac
	done
	shift $((${OPTIND} - 1))

	for _origin in "${@}"; do
		# origin cannot be a flag starting with '-' and must include
		# '/'.
		if ! echo "${_origin}" | egrep -q '^[^-].*/'; then
			die "Invalid origin: ${_origin}."
		fi
		_origins="${_origins} ${_origin}"
	done

	[ ${_all} -eq 0 ] && [ -z "${_files}" ] && [ -z "${_origins}" ] && usage
	[ ${_all} -eq 1 ] && [ -n "${_files}" ] && usage
	[ ${_all} -eq 1 ] && [ -n "${_origins}" ] && usage
	[ -n "${_files}" ] && [ -n "${_origins}" ] && usage
	# _backup is optional.
	# _disk is optional.
	# _dryrun is optional.
	[ -n "${_host}" ] || usage
	[ -n "${_target}" ] || usage
	# _verbose is optional.
}

_build_local() {
	local _all _backup _disk _dryrun _files _host _origins _target _verbose
	local _flags

	build_options "${@}"

	REMOTE_DISK="${_disk}"
	REMOTE_DRYRUN="${_dryrun}"
	REMOTE_HOST="${_host}"
	REMOTE_USER="$(id -nu)"
	if [ $? -ne 0 ]; then
		die "Unable to get a user name."
	fi
	REMOTE_VERBOSE="${_verbose}"
	if [ "${REMOTE_VERBOSE}" -ge 2 ]; then
		set -x
	fi

	init_local "${_target}"

	_flags="-j ${_target} -p ${REMOTE_CHERIBSDPORTS_BRANCH}"
	if [ ${_all} -eq 1 ]; then
		_flags="${_flags} -a"
	fi
	_flags="${_flags} ${_files} ${_origins}"
	check sudo poudriere bulk ${_flags}

	if [ -n "${_backup}" ]; then
		info "Backup isn't implemented yet."
	fi
}

build() {
	local _all _backup _disk _dryrun _files _host _origins _target _verbose

	build_options "${@}"

	REMOTE_DISK="${_disk}"
	REMOTE_DRYRUN="${_dryrun}"
	REMOTE_HOST="${_host}"
	REMOTE_USER="$(sshcmd id -nu)"
	if [ $? -ne 0 ]; then
		die "Unable to get a user name."
	fi
	REMOTE_VERBOSE="${_verbose}"
	if [ "${REMOTE_VERBOSE}" -ge 2 ]; then
		set -x
	fi

	init

	# Execute the local part of the build command on a remote host.
	#
	# Don't use check() here as we might want to dry-run remote commands.
	sshcmd -t tmux new \
	    sh "${REMOTE_PATH_POUDRIEREINFRASTRUCTURE}/poudriere-remote.sh" \
	    _build_local "${@}"
}

main() {
	local _cmd

	_cmd="${1}"
	shift

	case "${_cmd}" in
	_build_local)
		_build_local "${@}"
		;;
	build)
		build "${@}"
		;;
	*)
		usage
		;;
	esac
}

main "${@}"
