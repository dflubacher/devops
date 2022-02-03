#!/usr/bin/env bash
# =============================================================================
# Create Ubuntu installer using autoinstall. (20.04 LTS)
# This script
#   1. downloads an Ubuntu 20.04 server iso.
#   2. copies autoinstall/cloud-init files into the installer (./autoinstall).
#   3. copies additional customized scripts into the installer (./autoinstall)
#      for use in the target system. These files can be used in late- and
#      early-commands to use them during installation or afterwards in the
#      running target system.
#   4. Repacks the iso and stores it in /tmp.
# The folder where this installer script is located contains standard setup
# files (e.g. main.yaml with apt configuration, timezone etc.), the asset
# specific folders contain files with asset specific instructions (e.g.
# storage, network, etc.).
#
# -----------------------------------------------------------------------------

# USAGE:
#     /path/to/modify-installer.sh --vars_file=path/to/asset/specific/variable/file
#
#     Required argument:
#     -vars_file: path of file with variables to replace in autoinstall files
#                 and files to copied into the iso for custom commands.
#                 The path must be relative to user's working directory.

# Requires:
#    - bash >4.3 (no check)
#    - sudo privileges
#    - xorriso apt package (unpack and pack iso)
#    - cloud-image-utils apt package (combine autoinstall yaml files)

# References:
# - https://ubuntu.com/server/docs/install/autoinstall
# - https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html

# TODO: - error handling and file paths checks.
#       - syntax, lower-case for local, all caps for exported
#         variables/constants.

###   Define some variables   #################################################
declare -a AUTOINSTALL_FILES_MERGED
declare -a ADDITIONAL_FILES_MERGED

declare -r SCRIPT_DIR=$(dirname "$0") > /dev/null

# URL of the original installer.
# ISO_WEBLINK="http://releases.ubuntu.csg.uzh.ch/ubuntu/focal/ubuntu-20.04.3-desktop-amd64.iso"
ISO_WEBLINK="https://cdimage.ubuntu.com/ubuntu-server/focal/daily-live/current/focal-live-server-amd64.iso"
# ISO_WEBLINK="http://releases.ubuntu.csg.uzh.ch/ubuntu/focal/ubuntu-20.04.3-live-server-amd64.iso"

# Working directories and output.
ISO_ORIG=/tmp/ubuntu-amd64.iso
# If ISO_FILES structure is changed, check clean up condition in main().
ISO_FILES=$(mktemp --tmpdir -d "ubuntu-amd64-files_XXX")
ISO_NEW=/tmp/ubuntu-amd64-autoinstall.iso
TMP_SCRATCH_DIR=$(mktemp --tmpdir -d "ubuntu-scratch-files_XXX")
MBR_TEMPLATE=/tmp/isohdpfx.bin

# http://www.gnu.org/savannah-checkouts/gnu/bash/manual/bash.html#Shell-Parameter-Expansion
VARS_FILE=${VARS_FILE:-"assets/qemu/vars.env"}
VARS_FILE_DEFAULT=${VARS_FILE_DEFAULT:-"./vars.env"}



###   Define sub-functions   ##################################################
source_and_merge() {
   # source_and_merge VARS_FILE ARRAY_NAME1 ARRAY_NAME_2
   #
   # Assumes that array to be merged in is already declared (no check) and
   # named `ARRAY_NAME<#>_MERGED`.
   # Assumes that function is called from the root folder of the relative path
   # of the VARS_FILE.

   if [ "$#" -lt 1 ]; then
      echo "read_file_links: missing argument(s)."
      return 1
   fi

   # Expand path and jump to directory of the VARS_FILE to expand all paths
   # defined therin.
   local VARS_ENV=$(realpath "${1}")
   local VARS_ENV_DIR=$(dirname ${VARS_ENV})

   pushd "${VARS_ENV_DIR}" > /dev/null

   # Source the variable file.
   set -a
   . "${VARS_ENV}"
   set +a

   # Merge file by creating a name reference to the ARRAY_NAME<#>_MERGED and
   # add the expanded paths to it.
   for arg in "${@:2}"; do
      array="${arg}[@]"
      [ -v ${array} ] || { echo "${arg} is not set."; continue; }

      # array_ref=${tmp}"[@]"
      declare -n array_ref="${arg}_MERGED"

      for path in ${!array}; do
         # echo "current: ${path}"
         array_ref+=($(realpath "${path}"))
         # echo "array_ref: ${array_ref[@]}"
      done
      # Remove name reference for next use.
      unset -n array_ref
   done
   popd > /dev/null
}


main() {
   trap 'rm -rf "${TMP_SCRATCH_DIR}"; rm -rf "${MBR_TEMPLATE}"' EXIT

   # Parse arguments:
   # https://stackoverflow.com/a/14203146
   local non_default=0
   while [ $# -gt 0 ]; do
      case $1 in
         -v=* | --vars_file=*)
            VARS_FILE="${1#*=}"
            ;;
         -v | --vars_file)
            VARS_FILE="$2"
            shift # past argument
            ;;
         -vd=* | --vars_file_default=*)
            VARS_FILE_DEFAULT="${1#*=}"
            non_default=1
            ;;
         -vd | --vars_file_default)
            VARS_FILE_DEFAULT="$2"
            non_default=1
            shift # past argument
            ;;
      esac
      shift
   done

   # Clean up if necessary:
   [ -f ${ISO_NEW} ] && sudo rm -rf ${ISO_NEW}
   # Remove previous ISO_FILES directory:
   sudo find /tmp -type d -name "ubuntu-amd64-files_*" -exec rm -r {} \; -prune

   # --------------------------------------------------------------------------
   # VARS default
   # If --vars_file_default is provided as argument, it can be treated like
   # the custom --vars_file and handle the directory change in the
   # source_and_merge function. Otherwise switch to the script's directory and
   # evaluate the file from there, because the default's vars file should be
   # relative to this directory.
   ! [ ${non_default} ] || pushd ${SCRIPT_DIR} > /dev/null

   # The following files are part of autoinstall yaml files that are supposed
   # not to be changed.
   # The main.yaml contains timezone, apt configuration and packages, the
   # identity file contains account setup information variables..
   source_and_merge ${VARS_FILE_DEFAULT} "AUTOINSTALL_FILES" "ADDITIONAL_FILES"

   ! [ ${non_default} ] || popd > /dev/null

   # --------------------------------------------------------------------------
   # VARS user
   source_and_merge ${VARS_FILE} "AUTOINSTALL_FILES" "ADDITIONAL_FILES"

   # echo "autoinstall_merged: ${AUTOINSTALL_FILES_MERGED[@]}"
   # echo "additional_merged: ${ADDITIONAL_FILES_MERGED[@]}"


   # --------------------------------------------------------------------------
   # Merge all autoinstall files into user-data.
   # Replace all environment variables in the autoinstall files, and use a
   # temporary folder to store the result.
   echo
   echo "##### Merge autoinstall files..."

   # Substitute all variables in the cloud-init files.
   for ((i = 0; i < ${#AUTOINSTALL_FILES_MERGED[@]}; ++i)); do
      # Create file names in the temporary folder to fill in in the next step.
      USER_DATA[$i]=$(echo "${TMP_SCRATCH_DIR}/$(basename ${AUTOINSTALL_FILES_MERGED[$i]})")
      # Fill substituted cloud-init files in. Only those that are defined
      # otherwise some file local variables might be converted to blank.
      # https://unix.stackexchange.com/a/492778
      cat ${AUTOINSTALL_FILES_MERGED[$i]} | envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" > ${USER_DATA[$i]}
   done


   # --------------------------------------------------------------------------
   echo
   echo "##### Download Ubuntu installer..."
   # Check if link is valid. `--head` to only fetch the header, `--output` sent
   # to null to avoid header being printed to the output. `-L` to get response
   # even if server had to redirect (HTTP code 302). `--silent` to prevent
   # status being printed out.
   LINK_STATUS=$(curl -L --write-out '%{http_code}' --head --silent --output /dev/null ${ISO_WEBLINK})
   # echo ${LINK_STATUS}

   if [ -f ${ISO_ORIG} ]; then
      echo ">>>> File does already exist!"
   elif  [ ${LINK_STATUS} -ne 200 ]; then
      echo ">>>> Weblink returns HTTP code ${LINK_STATUS}. Terminating."
      exit
   else
      curl -Lo "${ISO_ORIG}" ${ISO_WEBLINK}
   fi


   # --------------------------------------------------------------------------
   # The iso file cannot be directly extracted and modified since it results in
   # a write-protected file system (see ISO 9660). Therefore we need to copy
   # everything to our own working directory and create a new initrd iso image.
   echo
   echo "##### Extract original iso file..."
   # https://wiki.debian.org/ManipulatingISOs
   xorriso -osirrox on -indev ${ISO_ORIG} -extract / ${ISO_FILES} && chmod +w -R ${ISO_FILES}

   # Alternative using 7z. Somehow a [BOOT] folder is extracted, exclude it.
   # TODO: Permissions seem to be different.
   # 7z x -o${ISO_FILES} -x'![BOOT]' ${ISO_ORIG}


   # --------------------------------------------------------------------------
   echo
   echo "##### Adding files to new installer..."

   # Use the `write-mime-multipart` command from the package
   # `cloud-image-utils` to merge the different parts of USER_DATA into one
   # user-data file. Concatenating yaml files containing identical keys results
   # in only the last key to be considered.
   # https://github.com/canonical/cloud-utils/blob/main/bin/write-mime-multipart
   [ -d ${ISO_FILES}/autoinstall ] || mkdir ${ISO_FILES}/autoinstall
   # Usually throws SyntaxWarning:
   write-mime-multipart --output="${ISO_FILES}/autoinstall/user-data" ${USER_DATA[@]}

   # Also create the meta-data file but leave empty.
   touch ${ISO_FILES}/autoinstall/meta-data

   # Add custom files to the iso at ./autoinstall (these files can be used by
   # main.yaml to be copied on to the target system).
   for ((i = 0; i < ${#ADDITIONAL_FILES_MERGED[@]}; ++i)); do
      if [[ -d ${ADDITIONAL_FILES_MERGED[$i]} ]]; then
         # If it is a directory, copy it to the scratch folder and substitute
         # variables in all files.
         # TODO: not robust enough. File not checked for:
         #       - not binary
         #       - writable
         folder_name=$(basename ${ADDITIONAL_FILES_MERGED[$i]})
         cp -r ${ADDITIONAL_FILES_MERGED[$i]} "${TMP_SCRATCH_DIR}/"

         for file_name in $(find "${TMP_SCRATCH_DIR}/${folder_name}" -type f); do
            # Find should return absolute filepaths.
            cat ${file_name} | envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" > ${file_name}
         done

         # Now that all variables should be replaced, copy folder into the iso.
         cp -r "${TMP_SCRATCH_DIR}/${folder_name}" "${ISO_FILES}/autoinstall/"
      
      elif [[ -f ${ADDITIONAL_FILES_MERGED[$i]} ]]; then
         ADD_FILENAMES[$i]=$(basename ${ADDITIONAL_FILES_MERGED[$i]})
         cat ${ADDITIONAL_FILES_MERGED[$i]} | envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" > "${ISO_FILES}/autoinstall/${ADD_FILENAMES[$i]}"
      else
         echo "${ADDITIONAL_FILES_MERGED[$i]} is not valid"
         exit 1
      fi
   done


   # --------------------------------------------------------------------------
   echo
   echo "##### Modify configuration..."
   {
      pushd ${ISO_FILES} > /dev/null
      # GRUB (UEFI normally uses GRUB as bootloader):
      #     Add menuentry to boot/grub/grub.cfg.
      # ISOLINUX (older BIOS rely on SYSLINUX/ISOLINUX bootloaders):
      #     Add menuentry to isolinux/txt.cfg
      # https://askubuntu.com/a/839089
      # TODO: Is that all? Diff observed between Lat7490 and X201.
      sudo getfacl --absolute-names "${ISO_FILES}"/boot/grub/grub.cfg > "${TMP_SCRATCH_DIR}/acl_grub_cfg"
      sudo chmod +w "${ISO_FILES}"/boot/grub/grub.cfg

      sudo getfacl --absolute-names "${ISO_FILES}"/isolinux/txt.cfg > "${TMP_SCRATCH_DIR}/acl_txt_cfg"
      sudo chmod +w "${ISO_FILES}"/isolinux/txt.cfg

      # Add menu entry for autoinstall after the line specifying the timeout.
      # It will be the entry selected by default.
      # NOTE: the `autoinstall` keyword suppresses a prompt after the POST
      #       screen and basically just rolls over any pre-installed OS.
      sudo sed -i "/^set timeout=.*/a menuentry \"Ubuntu autoinstall\" {\n\tset gfxpayload=keep\n\tlinux    \/casper\/vmlinuz \"ds=nocloud;s=\/cdrom\/autoinstall\/\"\tquiet autoinstall ---\n\tinitrd   \/casper\/initrd\n}" "${ISO_FILES}"/boot/grub/grub.cfg

      sudo sed -i "s/^default live/default autoinstall\nlabel autoinstall\n\tmenu label ^Ubuntu autoinstall\n\tkernel \/casper\/vmlinuz\n\tappend initrd=\/casper\/initrd quiet autoinstall ds=nocloud;s=\/cdrom\/autoinstall\/ ---/g" "${ISO_FILES}"/isolinux/txt.cfg
      sudo setfacl --restore="${TMP_SCRATCH_DIR}/acl_grub_cfg"
      sudo setfacl --restore="${TMP_SCRATCH_DIR}/acl_txt_cfg"

      echo
      echo "##### Regenerating md5sum.txt..."
      sudo getfacl md5sum.txt > "${TMP_SCRATCH_DIR}/acl_md5sum_txt"
      chmod +w md5sum.txt
      # List all files except md5sum.txt (exclamation point for NOT), follow
      # all symbolic links (originally `-follow`, replaced by `-L`). `print0`
      # to generate one line with space as delimiter instead of one line per
      # file delimited by newline character. Pipe line into md5sum command.
      # Find will output the following warning:
      # ```
      # find: File system loop detected; ‘./ubuntu’ is part of the same file system loop as ‘.’.
      # ```
      # Pruning of the directory didn't help, therefore move it temporarily out
      # of the way.
      mv ./ubuntu /tmp/
      find -L -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt

      sudo setfacl --restore="${TMP_SCRATCH_DIR}/acl_md5sum_txt"
      mv /tmp/ubuntu .

      # -----------------------------------------------------------------------
      echo
      echo "##### Creating a new bootable ISO image..."
      # Debian documentation uses genisoimage to create new ISO image, but
      # apparently it is no longer actively maintained. Therefore use xorriso.
      # https://wiki.debian.org/RepackBootableISO


      echo "## 1. Extracting MBR template from iso..."
      # Use the MBR_Template of the original iso.
      # TODO: Which is the right count? Debian link above says 432,
      # https://help.ubuntu.com/community/InstallCDCustomization#Building_the_ISO_image
      # says 446.
      # Use 512 as the maximum: https://unix.stackexchange.com/a/254668
      # dd if="${ISO_ORIG}" bs=1 count=446 of="${MBR_TEMPLATE}"
      dd if="${ISO_ORIG}" bs=1 count=512 of="${MBR_TEMPLATE}"

      echo
      echo "## 2. Creating new iso..."
      xorriso -as mkisofs -r -V 'focal-autoinstall' \
         -cache-inodes -J -l \
         -isohybrid-mbr "${MBR_TEMPLATE}" \
         -partition_offset 16 \
         -c isolinux/boot.cat \
         -b isolinux/isolinux.bin \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
         -eltorito-alt-boot \
         -e boot/grub/efi.img \
            -no-emul-boot -isohybrid-gpt-basdat \
         -o "${ISO_NEW}" \
         "${ISO_FILES}"


      popd > /dev/null # ${ISO_FILES}
   }


}
main "$@"
