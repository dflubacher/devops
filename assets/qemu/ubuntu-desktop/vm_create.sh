#!/usr/bin/env bash

# Create virtual machine.
# optional positional arguments:
# 1 - storage_dir: absolute path where to store the main storage file
#                  (default: ~/pool)
# 2 - iso_file: absolute path to iso-file for the installation.


###   VM configuration   ######################################################
# Optional arguments for libvirt commands.
NAME='ubuntu-desktop-autoinstall'
DESCRIPTION='Ubuntu desktop autoinstalled'
VCPUS=2
MEMORY=2048
# Check `man truncate` for allowed SIZE argument.
STORAGE_SIZE="30G"

STORAGE_DIR=${1:-"/srv/vmstorage"}
ISO_FILE=${2:-"/tmp/ubuntu-amd64-autoinstall.iso"}

###   Network configuration   #################################################
# Enable bridged networking with host configuration.
MACVTAP=false
# NOTE: this only works for Ethernet NICs, KVM doesn't support WIFI adapters.
# see `Important Note: Unfortunately, wireless interfaces cannot be attached to
#      a Linux host bridge`.
# https://wiki.libvirt.org/page/Networking#Host_configuration_2
# If macvtap is used, specify the network interface on the host to attach to.
HOST_IFACE=wlp0s20f3

# see `man virt-install` for allowed values. The first three octets are fixed.
MAC='52:54:00:42:42:cd'

# Check if we are being sourced by another script or shell.
[[ "${#BASH_SOURCE[@]}" -gt "1" ]] && { return 0; }
declare -r SCRIPT_DIR=$(dirname "$0") > /dev/null

main() {
    pushd ${SCRIPT_DIR} > /dev/null

    [ -d "${STORAGE_DIR}" ] || sudo mkdir "${STORAGE_DIR}"
    sudo chown root:libvirt "${STORAGE_DIR}"
    sudo chmod 775 "${STORAGE_DIR}"

    echo
    echo "#####   Creating storage file..."
    storage_file=$(mktemp --tmpdir="${STORAGE_DIR}" "${NAME}_XXX.img")

    # Exit if previous command didn't work out (usually because of permission
    # issues).
    [ -f "${storage_file}" ] || exit
    sudo chown ${USER}:libvirt ${storage_file}

    # Create storage file.
    truncate -s "${STORAGE_SIZE}" "${storage_file}"

    # The os-variant could be updated with osinfo-db-tools, but otherwise just
    # use the latest available.
    if ${MACVTAP}; then
        virt-install --name "${NAME}" --description "${DESCRIPTION}" \
                    --memory ${MEMORY} \
                    --vcpus=2 --cpu host \
                    --boot loader=/usr/share/OVMF/OVMF_CODE.fd \
                    --disk path="${storage_file}",format=raw,device=disk,bus=virtio,cache=none \
                    --network type=direct,source="${HOST_IFACE}",mac="${MAC}",source_mode=bridge,model=virtio \
                    --graphics vnc,listen=0.0.0.0 \
                    --cdrom "${ISO_FILE}" \
                    --hvm --os-variant=ubuntu20.04 --noautoconsole
    else
        virt-install --name "${NAME}" --description "${DESCRIPTION}" \
                    --memory ${MEMORY} \
                    --vcpus=2 --cpu host \
                    --boot loader=/usr/share/OVMF/OVMF_CODE.fd \
                    --disk path="${storage_file}",format=raw,device=disk,bus=virtio,cache=none \
                    --graphics vnc,listen=0.0.0.0 \
                    --cdrom "${ISO_FILE}" \
                    --hvm --os-variant=ubuntu20.04 --noautoconsole
    fi

    popd > /dev/null
}
main "$@"
