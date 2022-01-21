# QEMU/KVM/libvirt notes
## virt-install
- [canonical reference](https://wiki.ubuntu.com/UEFI/virt-install)
- [autoinstall](https://ubuntu.com/server/docs/install/autoinstall-quickstart)

TODO: check if this [Red Hat installation instructions](https://access.redhat.com/documentation/en-us/red_hat_container_development_kit/2.1/html/installation_guide/installing_container_development_kit_on_red_hat_enterprise_linux) help. See install_vagrant.sh.
### Normal setup
Create storage:
```sh
truncate -s 30G ~/vm/focal30.img
```

```sh
virt-install --name "ubuntu2004_autoinstall" --description "Ubuntu 20.04 autoinstall" --memory 2048 --vcpus=2 --cpu host --boot loader=/usr/share/OVMF/OVMF_CODE.fd --disk path=~/vm/focal30.img,format=raw,device=disk,bus=virtio,cache=none --graphics vnc,listen=0.0.0.0 --cdrom /tmp/ubuntu-amd64-autoinstall.iso --hvm --os-variant=ubuntu20.04 --noautoconsole
```
Command assumes `ovmf` package installed.

NOTES:
- using the UEFI from `qemu-efi` (i.e. `loader=/usr/share/qemu-efi/QEMU_EFI.fd`) resulted in `Guest did not initialize the display (yet)` (hanged)

### Autoinstall (user-data and meta-data) in separate image.
```sh
sudo virt-install --name "ubuntu2004_autoinstall" --description "Ubuntu 20.04 autoinstall" --memory 2048 --vcpus=2 --cpu host --boot loader=/usr/share/OVMF/OVMF_CODE.fd --disk path=/tmp/focal30.img,format=raw,device=disk,bus=virtio,cache=none --disk path=/tmp/seed.iso,format=raw,device=disk,bus=virtio,cache=none --graphics vnc,listen=0.0.0.0 --cdrom /tmp/ubuntu-amd64.iso --hvm --os-variant=ubuntu20.04 --noautoconsole
```

### Teardown:
```sh
sudo virsh undefine --remove-all-storage ubuntu2004_autoinstall
```

### virt-manager remote connection
With special port and ssh certificate, the connection needs to be added using CLI.
```sh
virt-manager -c "qemu+ssh://<user>@<address>:<port>/system?keyfile=/path/to/identity/file"
```
TODO: why is it `system`?

> NOTE: If VM is run on remote machine, virt-install needs sudo for remote monitoring by virt-manager. 

### Copy out of VM using libvirt
```sh
sudo virt-copy-out -d <VM name> /var/log/installer/autoinstall-user-data /tmp
```
Even works if path is on dm_crypt.

## Vagrant and libvirt
JG book uses Vagrant and VirtualBox for VM testing. I favor KVM as VM provider (why? unclear, Red Hat uses KVM).
