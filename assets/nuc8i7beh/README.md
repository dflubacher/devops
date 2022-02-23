# Intel NUC8i7BEH
- [Product description](https://ark.intel.com/content/www/us/en/ark/products/126140/intel-nuc-kit-nuc8i7beh.html)

## Ansible example
```sh
poetry run ansible-playbook -i ansible/production ansible/server.yml --limit "nuc8i7beh" --ask-become-pass
```
## Network during installation
The network to use during installation is set to `auto` in `network.cfg`. For Wifi it is important to match the environment variables in `network.cfg` and `vars.env` with a working Wifi network.

## Configure Wifi for Debian
- The Debian installer uses `netcfg` to configure Wifi during installation. However, once booted into the installed system no Wifi connection is established and the Wifi adapter is down.
- Installing NetworkManager in the late_command creates a `/etc/NetworkManager/system-connections.d/<ssid>` configuration.

For a more dynamic handling of the networks, NetworkManager in combination with netplan.io is used.
- Install network-manager and netplan.io packages in late_command.
- Copy a netplan configuration (99-netplan-config.yaml) into `/etc/netplan/` and use `NetworkManager` as the renderer.
- Disable `networking.service`, enable `NetworkManager` and apply the netplan configuration.

## Helpful
- Check BIOS: `sudo dmidecode | less`