**WARNING: this is still work in progress and should be considered experimental.**

# Poudriere infrastructure for CheriBSD packages.

This repository includes files necessary to start a Poudriere host that can build and host CheriABI CheriBSD packages. At the moment, we focus only on CHERI-RISC-V.

## Installation

1. Install [FreeBSD](https://www.freebsd.org/where/).

   We tested [the VMDK image for amd64 13.0-RELEASE](https://download.freebsd.org/ftp/releases/VM-IMAGES/13.0-RELEASE/amd64/Latest/FreeBSD-13.0-RELEASE-amd64.vmdk.xz).

2. Create a zpool zdata.

   ```
   zpool create zdata
   ```

3. Create a file system for a CHERI software release.

   ```
   zfs create zdata/cheri
   ```

4. Fetch a [CHERI software release](https://cheri-dist.cl.cam.ac.uk/).

   We tested [the Summer 2021 release](https://cheri-dist.cl.cam.ac.uk/releases/2021.08/relnotes.html).

5. Extract the CHERI software release to zdata/cheri.

   ```
   tar -x -C /zdata/cheri -f /path/to/cheri-release.tar.gz --strip-components 1 cheri/
   ```

6. Create symbolic links for files from this repository.

   ```
   find etc usr -type f | xargs -I % ln -s "$(realpath . )/%" "/%"
   ```

7. Copy jail files from this repository.

   ```
   cp -a zdata/cheri/output/jail /zdata/cheri/output/
   ```

8. Install cheribuild dependencies.

   ```
   pkg install \
       autoconf \
       automake \
       bash \
       cmake \
       git \
       glib \
       gmake \
       gsed \
       libtool \
       ninja \
       pixman \
       pkgconf \
       python3 \
       texinfo
   ```

9. Build a pure-capability CHERI-RISC-V CheriBSD.

   ```
   /zdata/cheri/cheribuild/cheribuild.py --skip-update --no-skip-sdk --qemu/no-use-smbd sdk-riscv64-purecap
   ```

10. Fetch the QEMU BSD user-mode with CHERI-RISC-V CheriABI support.

    ```
    git clone --single-branch -b qemu-cheri-bsd-user git@github.com:CTSRD-CHERI/qemu.git /zdata/cheri/qemu-cheri-bsd-user
    ```

11. Build the user-mode.

    ```
    /zdata/cheri/cheribuild/cheribuild.py --config-file /usr/local/etc/qemu-cheri-bsd-user-cheribuild.json qemu
    ```

12. Create a jail.

    ```
    poudriere jail -c -j cheriabi -v 13.0-CURRENT -a riscv.riscv64c -m null -M /zdata/cheri/output/rootfs-riscv64-purecap
    ```

13. Create a ports tree.

    * If you don't want to modify ports:
      ```
      poudriere ports -c -p freebsd-ports-main -m git -U https://github.com/CTSRD-CHERI/freebsd-ports.git -B main
      ```
    * If you want to modify ports on your host, we recommend to clone a repository:
      ```
      git clone git@github.com:CTSRD-CHERI/freebsd-ports.git /path/to/freebsd-ports
      ```
      and import it as a ports tree:
      ```
      poudriere ports -c -p freebsd-ports-main -m null -M /path/to/freebsd-ports
      ```

## Related repos

* [CTSRD-CHERI/qemu](https://github.com/CTSRD-CHERI/qemu) ([qemu-cheri-bsd-user](https://github.com/CTSRD-CHERI/qemu/tree/qemu-cheri-bsd-user) branch);
* [CTSRD-CHERI/freebsd-ports](https://github.com/CTSRD-CHERI/freebsd-ports);
* [freebsd/poudriere](https://github.com/freebsd/poudriere).
