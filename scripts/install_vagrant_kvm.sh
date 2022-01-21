#!/usr/bin/env bash

# ============================================================================
# Vagrant
# v1.0.0, 2021-09-20
# ----------------------------------------------------------------------------

# Ensure apt is in non-interactive mode to avoid prompts.
export DEBIAN_FRONTEND=noninteractive

echo
echo "### Installing Vagrant ..."

# https://www.vagrantup.com/downloads
# (retrieved 2021-06-09).
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
# sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
# The above line doesn't work on derivatives of ubuntu
# (see here: https://askubuntu.com/a/1015561).
LSB_RELEASE=$(sed 's/UBUNTU_CODENAME=//;t;d' /etc/os-release)
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com ${LSB_RELEASE} main"

sudo apt-get update && sudo apt-get install -y vagrant

# ============================================================================
# KVM/QEMU
# libvirt (virsh)/KVM/qemu: provides an abstraction language to define and
# launch VMs, but is normally used just to launch single VMs.
# ----------------------------------------------------------------------------
#
# https://help.ubuntu.com/community/KVM/Installation
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils qemu-efi

# libvirt-dev was required for vagrant plugin to get installed.
# TODO: Check if it works with "no-install-recommends".
sudo apt-get install -y --no-install-recommends virt-manager libvirt-dev

# Make sure that user is added to group libvirt (requires logout/login).
sudo addgroup libvirt
sudo adduser `id -un` libvirt

# ============================================================================
# Vagrant plugin for libvirt
# ----------------------------------------------------------------------------
vagrant plugin install vagrant-libvirt

# =============================================================================
# Addtional packages necessary
# -----------------------------------------------------------------------------

# When using a Debian vagrant box, it says that "It appears your machine
# doesn't support NFS, or there is not an adapter to enable NFS on this
# machine for Vagrant".
# Did not happen for centos/7, but for debian/bullseye
sudo apt-get install -y nfs-common nfs-kernel-server

# ============================================================================
# Install tools for cloud-init
# ----------------------------------------------------------------------------
sudo apt-get install -y cloud-image-utils

# ============================================================================
# Ansible
# ----------------------------------------------------------------------------
# # Using apt:
# sudo apt update
# sudo apt-get install -y software-properties-common
# sudo add-apt-repository --yes --update ppa:ansible/ansible
# sudo apt-get install -y ansible
#
# Alternative using python (depends on python3-dev and python3-pip).
# python3 -m pip install ansible

