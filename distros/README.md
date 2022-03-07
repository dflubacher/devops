# Distros
This folder contains common scripts, files and configurations that are associated with installing the corresponding operating system (`ubuntu` and `debian`).

This includes:
- an OS-specific `modify-installer.sh` file that downloads an OS installer file and copies preseed/autoinstall files and optionally additional files into the installer.
- OS-specific configuration files, containing settings that are considered to be independent of the hardware (e.g. initial user, timezone, mirror etc.):
    * Debian: main.cfg, identity.cfg
    * Ubuntu: main.yaml, identity.yaml
  These files are combined with autoinstall/preseed of the specific asset (which contains e.g. partitioning layout, network configuration)
- the .env. files define "environment variables" to be replaced in the preseed/autoinstall files.

NOTE: preseed files are split into different files similar to the autoinstall files in order to group settings into better manageable parts. However, the preseed files must not contain the same keys (`d-i ...`), whereas merging autoinstall files with identical keys is possible (with the `merge_how` dictionary at the top of the files).