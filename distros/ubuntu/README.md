# Simple Ubuntu 20.04 desktop using autoinstall
The goals are to set up:
- automated install of Ubuntu Desktop 20.04
- using Wifi or Ethernet
- with minimum bloatware
- Full Disk Encryption
- Ansible to complete the setup and its configurations
- Yubikey to unlock the LUKS container

Directions:
- Use autoinstall for initial setup (i.e. until Ansible can take over):
    * Desktop version seems not (yet?) to support autoinstall and preseeding using a Debian approach fails with kernel panic.
    * partitioning using [curtin notation](https://curtin.readthedocs.io/en/latest/topics/storage.html) (see storage.yaml in lat7490, qemu folder)
    * install poetry at first login (user land)
    * Ubuntu 20.04 with Full Disk Encryption (single user therefore no separate $HOME folder encryption)
- Ansible
    * run with local connection
- No bloatware
    * Install Ubuntu server and disable sshd
    * Install Ubuntu desktop minimal package
    * any drawbacks with this approach?
        * The server uses `systemd-networkd` to manage connections, the desktop uses `NetworkManager`. Doesn't make a difference in behavior for Ethernet connections, but the Wifi has issues: no wifis are visible in the corresponding settings-tab, although the laptop is connected over Wifi. Startup is delayed on `Host and DNS name lookup`, as NetworkManager tries to claim the wifi adapter. Therefore set the renderer at the appropriate time. The installer per default uses networkd (at least the server installer), so add `netplan set renderer=NetworkManager` during the `late-commands` and disable the network socket and service (afaik it's not recommended to have both running simultaneously). See also [this thread](https://discourse.ubuntu.com/t/automated-server-install-quickstart/16614/30).

## Organization
- This folder holds scripts and settings that are set per default for this operating system
    * vars.env contains some file links (e.g. main.yaml and identity.yaml)
    * main.yaml defines ubuntu mirrors, default packages, timezone etc.
    * modify-installer.sh is the script to create a modified iso containing the autoinstall configuration and additional files. It reads in the vars.env of this folder and the asset specific vars.env.
- Asset specific folder (e.g. lat7490)
    * vars.env with file links to autoinstall files and additional files to be copied into the installer.
    * the asset specific autoinstall files are usually storage and network.

## Procedure
1. In the asset folder (e.g. `lat7490`) adapt storage.yaml and network.yaml
    * In storage.yaml: use the `serial` for type `disk`. This helps to mitigate the risk of formatting the wrong disk. Get the serial:
        ```sh
        udevadm info --query=all --name=/dev/sda3 | grep "ID_SERIAL"
        ```
    * Adapt layout to specific asset.
2. Every autoinstall yaml file needs to contain these first lines in order for autoinstall/cloud-init to merge them properly. Otherwise only the last value for a specific key is considered. The `modify-installer.sh` uses `write-mime-multipart` to combine the files into `user-data`:
    ```yaml
    #cloud-config
    merge_how:
    - name: list
        settings: [append]
    - name: dict
        settings: [no_replace, recurse_list]
    ```
    Alternatively put everything into one file. Using `replace` could probably be used to replace keys in the default yaml files.
3. if necessary create custom scripts to be copied into the installer.
4. Fill out vars.env file with personalized information (username, network access credentials, file links to include, ...).
5. run `modify-installer.sh` script to create iso
6. create installation medium
7. install on system
8. after first login, poetry will be installed (see below)
9. copy or download repository
10. run playbook
11. optionally run `setup_yubikey_LUKS.sh` to enroll a YubiKey for the LUKS container.


## Known issues
### Yubikey setup
The yubikey is not automatically enrolled during the setup. The setup script is copied to `/usr/local/bin` and can be called interactively with `$ setup_yubikey_LUKS.sh`.

### Google Chrome apt repository
After running the playbook of lat7490, the google-chrome.list in `/etc/apt/apt.conf.d/` contains an additional line without `signed-by` (in contrast to the playbook one). This results in a conflict during `apt update`. Removing the unsigned line is not useful, as Google Chrome apparently replaces it.

### swap file (blank screen/sleep freeze)
Ubuntu 20.04 autoinstall configures the swap partition specified in storage.yaml correctly, including the entry in /etc/fstab. However, there also is an additional swap file at `/swap.img`. It seems that this causes problems at blank screen/sleep/suspend (freezes).

How to check:
- `free` has shown swap with about 4 GB larger than my swap partition.
- `swapon -s` has shown two entries, `/swap.img` and `/dev/dm-2`
- Entry in /etc/fstab for swap.img

Workaround:
- manual:
    ```sh
    swapoff /path/to/swap.img
    ```
- Ansible playbook using the mount module (see lat7490)
### Unable to use array variables in early- and late-commands
ADDITIONAL_FILES and AUTOINSTALL_FILES file references defined in vars.env are only used by modify-installer.sh to copy them into the installer. The variables cannot be used in the autoinstall yaml files to copy them from the installer into the target system. Instead they have to be written out in the form `/cdrom/autoinstall/<basename.ext>` where basename.ext is the corresponding file name.

### Second terminal on first login
TODO: check why it is called. Observed with latest daily build (2022-01-20)
### Locale generation
Probably related to ubuntu-desktop-minimal, the settings dialog `Region & Language` seems empty/default.
Ansible playbook is updated to install en_US and de_CH, but the formats need to be configured also.
## Notes
### Debian style preseeding vs. autoinstall
Ubuntu 20.04 server doesn't support preseed (debconf-set-selections) anymore. Tried preseeding with Desktop version, but to no avail (kernel panic).
> NOTE: `autoinstall` keyword in grub.cfg doesn't prompt for automated installation, a thumb drive in the machine will therefore reformat and install everything without delay.

After installation, the final version of the autoinstall configuration can be found at `/var/log/installer/autoinstall-user-data`. The LUKS password is set to a temporary file `/tmp/luks-key-abcdefgh`.

### Run installation script on first login
Ansible could be run:
- as apt package (system wide)
- as Python package (system wide or in user land)

Usually the apt Ansible version lags slightly behind the Python Ansible version, therefore prefer the Python package.

In order to have a reproducible setup, the Ansible version is specified in the pyproject.toml file of this repository. Therefore, the only Python package to install is poetry, which in turn will take care of setting up this repository accordingly.

To reduce the number of manual steps, poetry is installed upon first login. This is done to install poetry in user land and not system wide.
- only install it on first login, i.e. .bashrc not suitable as condition to run installer as it is evaluated with every instance of a terminal.
- Ubuntu Desktop already has an initial dialog (uses XDG autostart entry). Not if `--no-install-recommends ubuntu-desktop-minimal` is used.
- XDG autostart defines a method for autostarting applications on desktop environments.

#### Execute script at initial login on Ubuntu desktop
Hijack the initial Ubuntu dialog by copying its executable and call it after the custom initial-login script is done. Unfortunately poetry requires logout/login to be usable (sourcing .profile is working for the current shell only).
Then download/copy this repository, change to its root directory and run `poetry update`. This sets up the virtual environment and installs Ansible.

Then the playbook can be run:
```sh
poetry run ansible-playbook -i hosts.ini --ask-become-pass playbook.yaml
```
- `ansible_user`, `git_username` and `git_email` are set as variables in hosts.ini

#### For Ubuntu server
In case of servers Ansible would run per remote ssh connection, therefore only the sshd configuration has to be set up.


### Wifi
Wifi needs to have `wpasupplicant` installed. Apparently this package is available in the installer per default but not installed, therefore install it in early commands (see network.yaml of lat7490).
This is obviously asset specific, therefore not done per default.
>NOTE: Not sure if that is all there is to it.

### Writing iso to thumb drive:
Assuming thumb drive is `/dev/sdb` and iso was created in `/tmp`:
```sh
# Wipe first sectors of USB stick.
sudo dd if=/dev/zero of=/dev/sdb count=1000 bs=1M && sync
# Write iso image.
sudo dd if=/tmp/ubuntu-amd64-autoinstall.iso of=/dev/sdb bs=32M status=progress && sync
```

### Yubikey setup
After the Ansible playbook is completed, `yubikey-luks` should be istalled.

To prepare the Yubikey, configure slot 2 of the Yubikey to use HMAC-SHA1 which is disabled by default.
```sh
ykpersonalize -2 -ochal-resp -ochal-hmac -ohmac-lt64 -oserial-api-visible
# Select y to commit.
```

Then configure a slot on the partition containing the LUKS container for usage with the Yubikey:
```sh
# -d designates the LUKS device.
# -s could be used to define the slot 0..7, default to 7.
sudo yubikey-luks-enroll -d /dev/vda3
```

Add the following line to `/etc/crypttab`:
```sh
sudo sed -i -e "s|$|,keyscript=/usr/share/yubikey-luks/ykluks-keyscript|" /etc/crypttab
```
Update the initramfs
```sh
sudo update-initramfs -u
```
Now, after reboot, the LUKS prompt should ask for the Yubikey passphrase.

### Backup the LUKS header
Single point of failure, backup the LUKS header to a secure location outside the LUKS container.
```sh
sudo cryptsetup luksHeaderBackup <LUKS device e.g. /dev/sda3> --header-backup-file <path/to/file>
```

> See scripts/setup_yubikey_LUKS.sh.
### References
- [askubuntu](https://askubuntu.com/a/599826)
- [website with details for LVM and LUKS setup](https://oak-tree.tech/blog/lvm-luks)

Slightly outdated:
- [Article in german](https://deisi.github.io/posts/luks_mi_yubikey)
- [Mimacom blog](https://blog.mimacom.com/fde-with-yubikey/)
- [techrepublic blog](https://www.techrepublic.com/article/how-to-use-a-yubikey-on-linux-with-an-encrypted-drive/)






