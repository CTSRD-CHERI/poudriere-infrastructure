**WARNING: this is still work in progress and should be considered experimental.**

# Poudriere infrastructure for CheriBSD packages.

This repository includes files necessary to start a Poudriere host that can build and host CheriABI CheriBSD packages for Morello and CHERI-RISC-V.

## Installation

1. Install [FreeBSD](https://www.freebsd.org/where/) with an additional disk for a zpool (let's call it mydisk0).

   We tested [a VMDK snapshot image for amd64 14.0-CURRENT](https://download.freebsd.org/ftp/snapshots/VM-IMAGES/14.0-CURRENT/amd64/Latest/FreeBSD-14.0-CURRENT-amd64.vmdk.xz).

2. Create a user (let's call it myuser) and log in the host as the user.

2. Create a zpool zdata.

   ```
   sudo zpool create zdata mydisk0
   ```

3. Create file systems for CHERI and Poudriere.

   ```
   sudo zfs create zdata/cheri
   sudo zfs create zdata/distfiles
   sudo zfs create zdata/poudriere
   ```

4. Set the owner of new directories to your user.

   ```
   sudo chown myuser /zdata/cheri /zdata/distfiles /zdata/poudriere
   ```

5. Install cheribuild dependencies.

   ```
   sudo pkg install \
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

6. Install Poudriere dependencies.

   ```
   sudo pkg install poudriere nginx
   ```

7. Clone cheribuild with the user mode support.

   ```
   git clone --branch qemu-cheri-bsd-user https://github.com/CTSRD-CHERI/cheribuild.git /zdata/cheri/cheribuild
   ```

8. Build the CheriABI BSD user mode.

   ```
   /zdata/cheri/cheribuild/cheribuild.py --source-root /zdata/cheri bsd-user-qemu
   ```

9. Build a pure-capability CheriBSD.

   * Morello:
     ```
     /zdata/cheri/cheribuild/cheribuild.py --source-root /zdata/cheri --no-skip-sdk --qemu/no-use-smbd sdk-morello-purecap
     ```
   * For CHERI-RISC-V:
     ```
     /zdata/cheri/cheribuild/cheribuild.py --source-root /zdata/cheri --no-skip-sdk --qemu/no-use-smbd sdk-riscv64-purecap
     ```

10. Clone the poudriere-infrastructure repository.

    ```
    git clone https://github.com/CTSRD-CHERI/poudriere-infrastructure.git /zdata/cheri/poudriere-infrastructure
    ```

11. Create symbolic links for configuration files from the poudriere-infrastructure repository.

    ```
    cd /zdata/cheri/poudriere-infrastructure
    find etc usr -type f -o -type l | xargs -I % sudo ln -s "`realpath . `/%" "/%"
    ```
    Examine ln(1) errors as some files might already exist. In such case, remove or move them aside, and execute the above command again.

12. Copy jail files from this repository.

    * For Morello:
      ```
      cd /zdata/cheri/poudriere-infrastructure
      cp -a zdata/cheri/output/jail-morello-purecap /zdata/cheri/output/
      ```
    * For CHERI-RISC-V:
      ```
      cd /zdata/cheri/poudriere-infrastructure
      cp -a zdata/cheri/output/jail-riscv64-purecap /zdata/cheri/output/
      ```

13. Move the pure-capability rtld aside to make space for an amd64 rtld.

    * For Morello:
      ```
      mv /zdata/cheri/output/rootfs-morello-purecap/libexec/ld-elf.so.1 /zdata/cheri/output/rootfs-morello-purecap/libexec/ld-cheri-elf.so.1
      cp /libexec/ld-elf.so.1 /zdata/cheri/output/rootfs-morello-purecap/libexec/ld-elf.so.1
      ```
    * For CHERI-RISC-V:
      ```
      mv /zdata/cheri/output/rootfs-riscv64-purecap/libexec/ld-elf.so.1 /zdata/cheri/output/rootfs-riscv64-purecap/libexec/ld-cheri-elf.so.1
      cp /libexec/ld-elf.so.1 /zdata/cheri/output/rootfs-riscv64-purecap/libexec/ld-elf.so.1
      ```

14. Configure binmiscctl(8).

    ```
    sudo service qemu_user_static start
    ```

15. Create a jail.

    * For Morello:
      ```
      sudo poudriere jail -c -j cheribsd-morello-purecap -v 14.0-CURRENT -a arm64.aarch64c -m null -M /zdata/cheri/output/rootfs-morello-purecap
      ```
    * For CHERI-RISC-V:
      ```
      sudo poudriere jail -c -j cheribsd-riscv64-purecap -v 14.0-CURRENT -a riscv.riscv64c -m null -M /zdata/cheri/output/rootfs-riscv64-purecap
      ```

16. Create a ports tree.

    * If you don't want to modify ports:
      ```
      sudo poudriere ports -c -p main -m git -U https://github.com/CTSRD-CHERI/freebsd-ports.git -B main
      ```
    * If you want to modify ports on your host, we recommend to clone a repository:
      ```
      git clone git@github.com:CTSRD-CHERI/freebsd-ports.git /path/to/freebsd-ports
      ```
      and import it as a ports tree:
      ```
      sudo poudriere ports -c -p main -m null -M /path/to/freebsd-ports
      ```

17. Start nginx to browse Poudriere reports.

    ```
    sudo service nginx start
    ```

18. Start a test package build.

    * For Morello:
      ```
      sudo poudriere bulk -j cheribsd-morello-purecap -p main ports-mgmt/pkg
      ```
    * For CHERI-RISC-V:
      ```
      sudo poudriere bulk -j cheribsd-riscv64-purecap -p main ports-mgmt/pkg
      ```

19. Open `http://<host>/` to observe a build status in your browser.

20. Your package repository should be accessible with:

    * For Morello:
      `pkg+http://<host>/packages/cheribsd-morello-purecap-main/`
    * For CHERI-RISC-V:
      `pkg+http://<host>/packages/cheribsd-riscv64-purecap-main/`

## Related repos

* [CTSRD-CHERI/qemu](https://github.com/CTSRD-CHERI/qemu) ([qemu-cheri-bsd-user](https://github.com/CTSRD-CHERI/qemu/tree/qemu-cheri-bsd-user) branch);
* [CTSRD-CHERI/freebsd-ports](https://github.com/CTSRD-CHERI/freebsd-ports);
* [freebsd/poudriere](https://github.com/freebsd/poudriere).
