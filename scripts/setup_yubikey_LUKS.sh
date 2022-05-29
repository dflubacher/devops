#!/usr/bin/env bash
# =============================================================================
# Set up Yubikey for accessing LUKS encrypted container.
# v0.1.0 2022-01-09
# -----------------------------------------------------------------------------

# Requires:
#  - sudo privileges
#  - yubikey-luks (apt package, will be installed if missing)

# Checked for:
# - YubiKey 5 NFC (USB-A)
# - YubiKey 5C NFC (USB-C)

# Parse arguments (TODO: test):
# https://stackoverflow.com/a/14203146
while [ $# -gt 0 ]; do
   case $1 in
      -c=* | --configure_hmac=*)
        SETUP_HMAC_SLOT2="${1#*=}"
        ;;
      -c | --configure_hmac)
        SETUP_HMAC_SLOT2="$2"
        shift # past argument
        ;;
      -d=* | --luks_device=*)
        DEV_CRYPT="${1#*=}"
        ;;
      -d | --luks_device)
        DEV_CRYPT="$2"
        shift # past argument
        ;;
      -s=* | --slot=*)
        CRYPT_SLOT=${1#*=}
        ;;
      -s | --slot)
        CRYPT_SLOT=$2
        shift # past argument
        ;;
   esac
   shift
done

SETUP_HMAC_SLOT2=${SETUP_HMAC_SLOT2:-"no"}
DEV_CRYPT=${DEV_CRYPT:-"/dev/loop0"}
CRYPT_SLOT=${CRYPT_SLOT:-0}


echo
echo "###############################################################################"
echo "##### Set up Yubikey to unlock crypt container                            #####"
echo "###############################################################################"

echo
echo "##### Making sure package yubikey-luks is installed:"

if ! [[  $(sudo dpkg -l | cut -d " " -f 3 | grep "^yubikey-luks" | wc -l) -gt 0 ]]; then
	echo
	echo ">>> yubikey-luks not found, installing ..."
	sudo apt-get update && sudo apt-get -y install yubikey-luks
fi

echo
while [ $(lsusb | grep -i yubikey | wc -l) -eq 0 ]; do
  read -n 1 -s -r -p "Error: No Yubikey found. Plug it in and press any key ..."
done

echo
while :; do
  read -ep "##### Do you want to set up slot 2 for HMAC-SHA1 (yes), or leave it (no)?: " SETUP_HMAC_SLOT2 </dev/tty
  case "${SETUP_HMAC_SLOT2}" in
    [yY][eE][sS] | [yY])
      # https://developers.yubico.com/yubico-pam/Authentication_Using_Challenge-Response.html
      sudo ykpersonalize -2 -ochal-resp -ochal-hmac -ohmac-lt64 -oserial-api-visible
      break
      ;;
    *)
      break
      ;;
  esac
lsblk
done

while ! $(sudo cryptsetup isLuks ${DEV_CRYPT}); do
  read -ep "##### Enter the device (e.g. /dev/sda3 or /dev/nvme0n1p3) that contains the crypt partition to enroll the yubikey for: " DEV_CRYPT </dev/tty
  # sudo cryptsetup isLuks ${DEV_CRYPT} && echo "is luks"
done


while ! [[ ${CRYPT_SLOT} =~ ^[1-7]+$ ]]; do
  read -ep "##### Enter the slot of the LUKS device [1..7] to use: " CRYPT_SLOT </dev/tty
  [[ ${CRYPT_SLOT} =~ ^[1-7]+$ ]] || { echo "Enter a valid number"; continue; }
done

echo
echo "##### Enrolling yubikey, follow the dialog..."
echo
sudo yubikey-luks-enroll -d ${DEV_CRYPT} -s ${CRYPT_SLOT}

echo
echo "##### Modifying /etc/crypttab..."
crypttab_mod="keyscript=/usr/share/yubikey-luks/ykluks-keyscript"
if ! grep -Fq "${crypttab_mod}" /etc/crypttab; then
  sudo sed -i -e "s|$|,${crypttab_mod}|" /etc/crypttab
fi


echo
echo "##### Updating initramfs..."
sudo update-initramfs -u

echo
echo "luksDump: "
sudo cryptsetup luksDump ${DEV_CRYPT}

echo
date_today=$(date +"%Y-%m-%d")
host_name=$(hostname)
backup_file="/tmp/${date_today}_${host_name}_LUKS_backup.bin"
sudo cryptsetup luksHeaderBackup ${DEV_CRYPT} --header-backup-file ${backup_file}
# Backup file is owned by root which makes exporting it only possible by root.
sudo chown $(whoami) ${backup_file}
echo "##### Backup LUKS header done: Please move it from /tmp/<date>_LUKS_backup.bin to an secure, offline location..."

