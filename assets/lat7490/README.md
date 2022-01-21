# Dell Latitude 7490
For the Dell Latitude 7490, a dual boot Ubuntu 20.04/Win11 is used:
- Ubuntu 20.04 as main development environment.
- Win 11 for win-based applications (e.g. CODESYS 3, PDF X-Change, etc.). The installation of Windows is not automated.
### Disk layout
- 500 GB SATA SSD (TODO: replace)
    * UEFI
    * BOOT
    * CRYPT (>256 GB)
        * ROOT
        * SWAP
    * Win (>150 GB)
## Enrolling Lenovo Thunderbolt 3 Dock
1. Plug in dock
2. `boltctl list` should show the dock with type, name, vendor, uuid etc.
3. `boltctl enroll <uuid>` authorizes and stores a device in the database.

### Windows
Windows installation is not automated.
Using dd to create a bootable Windows installation does not work:
```sh
sudo dd if=/dev/zero of=/dev/sdb count=10000 bs=1 status=progress && sync
sudo dd if=~/Downloads/Win11_English_x64v1.iso of=/dev/sdb bs=32M   status=progress && sync
```

The reason seems to be a file called `install.wim` which is somewhere around 4.8 GB (some blogs say that the newest Linux Kernel ^5.15 is able to handle ntfs better...). Somehow the thumb drive is not bootable, and the One-Time Boot menu doesn't detect any USB drive.

Followed [this blog](https://dellwindowsreinstallationguide.com/creating-a-windows11-bootable-usb-on-linux/) which worked, basically:
1. Use gparted to create gpt partition table
2. Add partition (1024MiB) named `BOOT` and format FAT32
3. Add partition (rest) named `INSTALL` and format NTFS
4. Mount iso (Disk Image Mounter), or use `sudo mount -t udf -o loop,ro,unhide /path/to/file.iso /mnt`
5. Copy everything except `sources` to `BOOT`
6. mkdir `sources` in `BOOT` and copy file `boot.wim` to `BOOT/sources`
7. Copy everything from mounted image to `INSTALL`

Done. Install from USB (using partition 2 worked). Probably using rufus on another Windows machine might be a better idea.

#### Grub
Two enable the grub menu for the dual boot setup, open the one-time boot (F12) menu after installing Windows and select ubuntu to boot.
Once logged in, update the grub menu
```sh
sudo update-grub
```
This should find both ubuntu and Windows OS. However check the boot sequence in the Boot setup and make sure that Ubuntu is first, otherwise no Grub menu will show up.