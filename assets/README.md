# Assets
Descriptive configurations of all assets used.

The goals of this section:
- Having shell scripts only where necessary (e.g. to create a modified iso).
- Having as few manual steps as possible.
- Easily repeatable/restorable setups.

Current directions followed:
- Use preseeding for Debian 11 and autoinstall/cloud-init for Ubuntu 20.04, but only as much as needed for a base system installation.
    * preseeding is put into initrd for Debian 11, as it doesn't require to modify any of the grub menues and is found automatically.
    * autoinstall files (basically cloud-init user and meta data) could be passed in as separate disk for virtual machines. For bare metal, the files have to be packed into the iso (which in turn could also be used for Virtual Machines).
- Use Ansible playbooks to take it from there. This means servers need an sshd service configured or playbooks are run locally.

Ansible doesn't need an agent running on the asset.
- TODO: compare to Puppet, Chef, or Terraform
    * It seems that Puppet and Chef can be set up as part of cloud-init

## Organization
There are currently two categories of assets:
- bare-metal or emulators
- operating systems

They are placed on the same level since putting the operating systems as subfolders to the bare-metal folders would result in potentially duplicate files in the repository.
- The operating systems (currently folder `ubuntu` and `debian`) contain common scripts, files and configurations that are associated with installing the corresponding OS.
- the bare-metal folders (`lat7490`, `qemu`) hold files and configurations specific for that asset.
