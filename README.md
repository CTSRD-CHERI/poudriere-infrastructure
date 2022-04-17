**WARNING: this is still work in progress and should be considered experimental.**

# Poudriere infrastructure for CheriBSD packages.

This repository includes files necessary to bootstrap a Poudriere host that can build and host CheriABI and plain ABI CheriBSD packages for Morello and CHERI-RISC-V.

## Automated package building

[poudriere-remote.sh](poudriere-remote.sh) allows to bootstrap a package building environment for a selected [cheribuild](https://github.com/CTSRD-CHERI/cheribuild) OS target and build packages using a [CheriBSD ports tree](https://github.com/CTSRD-CHERI/cheribsd-ports).

This script requires root access via sudo to a remote host and should only be used with hosts created specifically for package building purposes.

## Manual package building

You can create a Poudriere environment without [poudriere-remote.sh](poudriere-remote.sh). Read more on manual configuration [here](https://github.com/CTSRD-CHERI/poudriere-infrastructure/wiki/Host-configuration).

## Package signing

[key.sh](key.sh) allows to generate a signing key and sign a package repository built by Poudriere using a separate package signing host.

## Related repos

* [CTSRD-CHERI/qemu](https://github.com/CTSRD-CHERI/qemu) ([qemu-cheri-bsd-user](https://github.com/CTSRD-CHERI/qemu/tree/qemu-cheri-bsd-user) branch);
* [CTSRD-CHERI/cheribuild](https://github.com/CTSRD-CHERI/cheribuild) ([qemu-cheribsd-user](https://github.com/CTSRD-CHERI/cheribuild/tree/qemu-cheri-bsd-user) branch);
* [CTSRD-CHERI/cheribsd](https://github.com/CTSRD-CHERI/cheribsd) ([dev](https://github.com/CTSRD-CHERI/cheribsd/tree/dev) branch);
* [CTSRD-CHERI/cheribsd-ports](https://github.com/CTSRD-CHERI/cheribsd-ports);
* [freebsd/poudriere](https://github.com/freebsd/poudriere).
