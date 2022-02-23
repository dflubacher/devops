# DevOps
Configuration management and provisioning of IT assets.

The goals of this repository are:
- Having shell scripts only where necessary (e.g. to create a modified iso).
- Having as few manual steps as possible.
- Easily repeatable/restorable setups.

Current directions followed:
- Use preseeding for Debian 11 and autoinstall/cloud-init for Ubuntu 20.04, but only as much as needed for a base system installation.
    * preseeding is put into initrd for Debian 11, as it doesn't require to modify any of the grub menues and is found automatically.
    * autoinstall files (basically cloud-init user and meta data) could be passed in as separate disk for virtual machines. But for bare metal, the files have to be packed into the iso (which in turn can also be used for Virtual Machines).
- Use Ansible playbooks to take it from there. This means servers need an sshd service configured or playbooks are run locally.

See pyproject.toml for Python requirements.

## Organization
Two aspects covered:
1. Automated installation of Debian/Ubuntu on bare metal assets (laptops, servers)
    * This is covered in the [assets](./assets/) folder, which is linked with the [distros](./distros/) folder. The [assets](./assets/) folder contains specific instructions for a certain system (e.g. network, storage, hostname configuration) which are then fed into a shell script within the [distros](./distros/) folder, which creates the selected installer iso.
2. Provisioning of systems
    * Currently, Ansible is used to provision a system to the desired state.
