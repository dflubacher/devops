# Dell Latitude 7490
For the Dell Latitude 7490, a dual boot Ubuntu 22.04/Win11 is used:
- Ubuntu 22.04 as main development environment.
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

Update Ubuntu 22.04 (Kernel 5.15):
1. Use gparted to create gpt partition table
2. format ntfs and label 'Win11USB202205' (or similar)
3. Mount iso file with Disk Mounter
4. Copy everything to ntfs partition.

Done. Install from USB (using partition 2 worked). Probably using rufus on another Windows machine might be a better idea.

#### Windows clock
It seems that Ubuntu per default uses UTC for the HW RTC, while Windows uses local time. Obviously, if both automatically sync the time, this causes problems.

Therefore:
- Use UTC for clock.
- Disable time synchronization in Windows (right-click clock and `Adjust Time & Date`), and uncheck corresponding slider.
- Open registry:
    * In folder `Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation`
    * New `DWORD`
    * Key: `RealTimeIsUniversal`
    * Modify value: 1 (hex)
- [Reference](https://ubuntuhandbook.org/index.php/2021/06/incorrect-time-windows-11-dual-boot-ubuntu/)

#### Grub
Two enable the grub menu for the dual boot setup, open the one-time boot (F12) menu after installing Windows and select ubuntu to boot.
Once logged in, update the grub menu
```sh
sudo update-grub
```
This should find both ubuntu and Windows OS. 
NOTE: Check the boot sequence in the Boot setup and make sure that Ubuntu is first, otherwise no Grub menu will show up.

TODO: Ubuntu 22.04 and its Grub 2.06 disabled the OS prober, and it therefore didn't detect Windows anymore. [Found this workaround](https://www.omgubuntu.co.uk/2021/12/grub-doesnt-detect-windows-linux-distros-fix), but it seems not to be the best solution.
```sh
Memtest86+ needs a 16-bit boot, that is not available on EFI, exiting
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
```