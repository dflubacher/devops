# QEMU/KVM/libvirt notes
## virt-install
- [canonical reference](https://wiki.ubuntu.com/UEFI/virt-install)
- [autoinstall](https://ubuntu.com/server/docs/install/autoinstall-quickstart)

TODO: check if this [Red Hat installation instructions](https://access.redhat.com/documentation/en-us/red_hat_container_development_kit/2.1/html/installation_guide/installing_container_development_kit_on_red_hat_enterprise_linux) help. See install_vagrant.sh.
### Normal setup
Create storage:
```sh
truncate -s 30G ~/vm/jammy30.img
```

```sh
virt-install --name "ubuntu2204_autoinstall" --description "Ubuntu 22.04 autoinstall" --memory 2048 --vcpus=2 --cpu host --boot loader=/usr/share/OVMF/OVMF_CODE.fd --disk path=~/vm/jammy30.img,format=raw,device=disk,bus=virtio,cache=none --graphics vnc,listen=0.0.0.0 --cdrom /tmp/ubuntu-amd64-autoinstall.iso --hvm --os-variant=ubuntu20.04 --noautoconsole
```
Command assumes `ovmf` package installed.

NOTES:
- using the UEFI from `qemu-efi` doesn't work on amd64 (i.e. `loader=/usr/share/qemu-efi/QEMU_EFI.fd`) resulted in `Guest did not initialize the display (yet)`. It should work for arm64, [see here](https://wiki.debian.org/UEFI#ARM64_platform:_UEFI.2C_U-Boot.2C_Fastboot.2C_etc.)

### Autoinstall (user-data and meta-data) in separate image.
```sh
sudo virt-install --name "ubuntu2204_autoinstall" --description "Ubuntu 22.04 autoinstall" --memory 2048 --vcpus=2 --cpu host --boot loader=/usr/share/OVMF/OVMF_CODE.fd --disk path=/tmp/jammy30.img,format=raw,device=disk,bus=virtio,cache=none --disk path=/tmp/seed.iso,format=raw,device=disk,bus=virtio,cache=none --graphics vnc,listen=0.0.0.0 --cdrom /tmp/ubuntu-amd64.iso --hvm --os-variant=ubuntu20.04 --noautoconsole
```

### Teardown:
```sh
sudo virsh undefine --remove-all-storage ubuntu2204_autoinstall
```

### virt-manager remote connection
With special port and ssh certificate, the connection needs to be added using CLI.
```sh
virt-manager -c "qemu+ssh://<user>@<address>:<port>/system?keyfile=/path/to/identity/file"
```


> NOTE: If VM is run on remote machine, virt-install needs sudo for remote monitoring by virt-manager. That is the reason for `/system?` in the above command. `/session?` is unfortunately [not supported for remote monitoring by libvirt](https://listman.redhat.com/archives/libvirt-users/2014-June/msg00102.html).
> Error would be: `Operation not supported: Connecting to session instance without socket path is not supported by the ssh transport`

### Copy out of VM using libvirt
```sh
sudo virt-copy-out -d <VM name> /var/log/installer/autoinstall-user-data /tmp
```
Even works if path is on dm_crypt. This requires libguestfs-tools.

### Copying in to VM
Usually VM should be stopped in order not to corrupt the filesystem, and sudo might be required. No flag for folders necessary.
```sh
sudo virt-copy-in -d debian11_preseed /tmp/SetupSTM32CubeMX-6.5.0 /home/debian/
```
This will place the file in the debian home folder with `debian:debian` ownership.


## Debian
```sh
sudo virt-install --name "debian11-preseed" --description "Debian 11 preseeded" --memory 2048 --vcpus=2 --cpu host --boot loader=/usr/share/OVMF/OVMF_CODE.fd --disk path=/home/jefe/pool/bullseye30g.img,format=raw,device=disk,bus=virtio,cache=none --graphics vnc,listen=0.0.0.0 --cdrom ~/debian-amd64-preseed.iso --hvm --os-variant=debian10 --noautoconsole
```

To get valid os-variants [libosinfo_bin](https://packages.ubuntu.com/jammy/libosinfo-bin) is needed.
Unfortunately neither the package for debian nor ubuntu has Bullseye in it, therefore use the next best.
```sh
osinfo-query os
```

## With OVMF UEFI
After installing Debian on qemu with OVMF UEFI, it initially booted only into the EFI shell.
Here is what I did:
- The map (or manually typing map) showed `FS0`. This seems to indicate that the UEFI found a partition with a recognized file system and mounted it.
- Typing `FS0:` and then `cd EFI`, `cd debian` shows `grubx64.efi`.
- Typing `grubx64.efi` boots Debian as expected.
- Alternatively, type `exit` go to `Boot Maintenance Manager` and select `Boot from file` to select the grubx64.efi.
- To do that automatically, do the following:
    * For just grub2:
        ```sh
        sudo cp /boot/efi/EFI/debian/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
        ```
    * For shim (secure boot):
        ```sh
        sudo cp /boot/efi/EFI/debian/shimx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
        sudo cp /boot/efi/EFI/debian/grubx64.efi /boot/efi/EFI/BOOT/grubx64.efi
        sudo cp /boot/efi/EFI/debian/grub.cfg /boot/efi/EFI/BOOT/grub.cfg
        ```
- [Ubuntu reference regarding this](https://wiki.ubuntu.com/UEFI/SecureBoot/Testing)

## Set IP for VM
```sh
virsh net-update default add ip-dhcp-host "<host mac='52:54:00:42:42:ab' name='qemu_nuc8i7beh' ip='192.168.122.124' />" --live --config
virsh net-update default add dns-host "<host ip='192.168.122.124'><hostname>qemu_nuc8i7beh</hostname></host>" --live --config
```
This results in an error if already defined.
- [libvirt reference](https://wiki.libvirt.org/page/Networking#virsh_net-update)

TODO: Get DNS to work.
- Easiest fix: add `192.168.122.124 qemu_nuc8i7beh` to /etc/hosts