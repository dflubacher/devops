# Install Debian 11
The goals are to set up:
- automated install of Debian 11 server using preseeding.
- using Wifi or Ethernet (depending on the network.cfg and vars.env of the asset)

Usage:
```sh
distros/debian/modify-installer.sh --vars_file assets/nuc8i7beh/vars-real.env
```
NOTE: the OS specific `vars.env` is included by default (same folder as `modify-installer.sh`)

### Writing iso to thumb drive:
Assuming thumb drive is `/dev/sdb` and iso was created in `/tmp`:
```sh
# Wipe first sectors of USB stick.
sudo dd if=/dev/zero of=/dev/sdb count=100000 bs=2048 && sync
# Write iso image.
sudo dd if=/tmp/debian-amd64-preseed.iso  of=/dev/sdb  bs=2048 status=progress && sync
```