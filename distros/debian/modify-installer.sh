#!/usr/bin/env bash
# =============================================================================
# Debian installer with preseed file.
# This script downloads a debian installer file, copies preseed configurations
# into it and creates an iso file that can be extracted to a bootable thumb
# drive.
# -----------------------------------------------------------------------------


# USAGE:
#     /path/to/modify-installer.sh --vars_file=path/to/asset/specific/variable/file
#
#     Required argument:
#     -vars_file: path of file with variables to replace in preseed files
#                 and files to copied into the iso for custom commands.
#                 The path must be relative to user's working directory.

# Requires:
#    - bash >4.3 (no check)
#    - sudo privileges
#    - xorriso apt package (unpack and pack iso)

# References:
#   - https://gist.github.com/zuzzas/a1695344162ac7fa124e15855ce0768f
#   - https://wiki.debian.org/DebianInstaller/Preseed/EditIso
#   - https://github.com/coreprocess/linux-unattended-installation


###   Define some variables   #################################################
declare -a PRESEED_FILES_MERGED
declare -a ADDITIONAL_FILES_MERGED

declare -r SCRIPT_DIR=$(dirname "$0") > /dev/null

# URL of the original installer.
# The Wifi usually needs some firmware (Debian calls it non-free firmware),
# therefore use the netinstaller with some firmware.
# See https://wiki.debian.org/Firmware
ISO_WEBLINK="https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/current/amd64/iso-cd/firmware-11.2.0-amd64-netinst.iso"
# ISO_WEBLINK="https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/11.2.0+nonfree/amd64/iso-cd/firmware-11.2.0-amd64-netinst.iso"

ISO_ORIG=/tmp/debian-amd64.iso
# If ISO_FILES structure is changed, check clean up condition in main().
ISO_FILES=$(mktemp --tmpdir -d "debian-amd64-files_XXX")
ISO_NEW=/tmp/debian-amd64-preseed.iso
TMP_SCRATCH_DIR=$(mktemp --tmpdir -d "debian-scratch-files_XXX")
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
   sudo find /tmp -type d -name "debian-amd64-files_*" -exec rm -r {} \; -prune

   # --------------------------------------------------------------------------
   # VARS default
   # If --vars_file_default is provided as argument, it can be treated like
   # the custom --vars_file and handle the directory change in the
   # source_and_merge function. Otherwise switch to the script's directory and
   # evaluate the file from there, because the default's vars file should be
   # relative to this directory.
   ! [ ${non_default} ] || pushd ${SCRIPT_DIR} > /dev/null

   # The following files are part of preseed files that are supposed not to be
   # changed.
   # The main.cfg contains timezone, apt configuration and packages, the
   # identity file contains account setup information variables..
   source_and_merge ${VARS_FILE_DEFAULT} "PRESEED_FILES" "ADDITIONAL_FILES"

   ! [ ${non_default} ] || popd > /dev/null

   # --------------------------------------------------------------------------
   # VARS user
   source_and_merge ${VARS_FILE} "PRESEED_FILES" "ADDITIONAL_FILES"

   # echo "preseed_merged: ${PRESEED_FILES[@]}"
   # echo "additional_merged: ${ADDITIONAL_FILES_MERGED[@]}"


   # --------------------------------------------------------------------------
   # Merge all preseed files into one single preseed.cfg.
   # Replace all environment variables in the preseed files, and use a
   # temporary folder to store the result.
   echo
   echo "##### Merge preseed files..."

   touch "${TMP_SCRATCH_DIR}/preseed.cfg"
   # Substitute all variables in the cloud-init files.
   for ((i = 0; i < ${#PRESEED_FILES_MERGED[@]}; ++i)); do
      # Create file names in the temporary folder to fill in in the next step.
      PRESEED_SUBST[$i]=$(echo "${TMP_SCRATCH_DIR}/$(basename ${PRESEED_FILES_MERGED[$i]})")
      # Fill substituted preseed files in. Only those that are defined
      # otherwise some file local variables might be converted to blank.
      # https://unix.stackexchange.com/a/492778
      cat ${PRESEED_FILES_MERGED[$i]} | envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" > ${PRESEED_SUBST[$i]}

      # Build up final preseed.cfg.
      cat ${PRESEED_SUBST[$i]} >> "${TMP_SCRATCH_DIR}/preseed.cfg"
      echo -e "\n" >> "${TMP_SCRATCH_DIR}/preseed.cfg"

   done


   # --------------------------------------------------------------------------
   echo
   echo "##### Download Debian installer..."
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
   # a write-protected file system (see ISO 9660). Therefore copy everything to
   # a working directory and create a new initrd iso image.
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
   # Add custom files to the iso at ./files (these files can be used by
   # late-commands to be copied on to the target system).

   [ -d "${ISO_FILES}/files" ] || mkdir -p "${ISO_FILES}/files"

   for ((i = 0; i < ${#ADDITIONAL_FILES_MERGED[@]}; ++i)); do
      ADD_FILENAMES[$i]=$(basename ${ADDITIONAL_FILES_MERGED[$i]})
      cat ${ADDITIONAL_FILES_MERGED[$i]} | envsubst "$(env | cut -d= -f1 | sed -e 's/^/$/')" > "${ISO_FILES}/files/${ADD_FILENAMES[$i]}"
   done

   # cp "${ISO_FILES}/preseed.cfg"


   # --------------------------------------------------------------------------
   echo
   echo "##### Modify configuration..."
   {
      pushd ${ISO_FILES} > /dev/null
      echo
      echo "##### Adding the preseed file to the initrd..."
      # In the working directory, we need to make the initrd.gz writable, uncompress
      # it and append the preseed file to the initrd.
      sudo getfacl -R --absolute-names "${ISO_FILES}" > "${TMP_SCRATCH_DIR}/acl_install_amd"
      sudo chmod +w -R "${ISO_FILES}"/install.amd/
      # Uncompress the archive (which results in an uncompressed archive in the same
      # directory).
      gunzip "${ISO_FILES}"/install.amd/initrd.gz
      # cpio takes a list of file names and copies them into an archive or in our
      # case, into an existing archive.
      #   -H newc: use archive format newc
      #   -o: `--create`: run in copy-out mode
      #   -A: append to existing archive
      #   --no-absolute-filenames: create all files relative to the current directory.
      #   --file=, -F: Archive file name instead of standard input or output.
      # TODO: currently need to change to the directory of the preseed file,
      #       because cpio creates the file at the relative location.
      pushd ${TMP_SCRATCH_DIR} > /dev/null
      echo "./preseed.cfg" | cpio -H newc -o -A --no-absolute-filenames --file="${ISO_FILES}/install.amd/initrd"
      popd > /dev/null
      # Recompress the initrd and return initrd.gz to its original read-only state.
      gzip "${ISO_FILES}"/install.amd/initrd

      sudo setfacl --restore="${TMP_SCRATCH_DIR}/acl_install_amd"


      echo
      echo "##### Modifying boot menues..."
      # By putting the preseed in the initrd, the boot menu doesn't need to be
      # updated (tested for UEFI).

      # If the preseed is not put into the initrd, the following changes in the
      # boot menues is necessary.
      # GRUB (UEFI normally uses GRUB as bootloader):
      #     Add menuentry to boot/grub/grub.cfg.
      # ISOLINUX (older BIOS rely on SYSLINUX/ISOLINUX bootloaders):
      #     Add menuentry to isolinux/txt.cfg
      # https://askubuntu.com/a/839089

      # Calculate the preseed md5sum.
      PRESEED_MD5SUM=$(md5sum "${TMP_SCRATCH_DIR}/preseed.cfg" | awk '{print $1;}')

      # isolinux menu:
      sudo getfacl --absolute-names "${ISO_FILES}/isolinux/txt.cfg" > "${TMP_SCRATCH_DIR}/acl_txt_cfg"
      sudo chmod +w "${ISO_FILES}"/isolinux/txt.cfg
      sudo sed -i "1i\prompt 0\ntimeout 1\n\ndefault preseed\nlabel preseed\n\tmenu label ^Auto with preseed\n\tkernel \/install.amd\/vmlinuz\n\tappend vga=788 initrd=/\install.amd\/initrd.gz preseed\/file=\/cdrom\/preseed.cfg preseed\/file\/checksum=${PRESEED_MD5SUM}\n" "${ISO_FILES}/isolinux/txt.cfg"
      sudo setfacl --restore="${TMP_SCRATCH_DIR}/acl_txt_cfg"

      # grub menu:
      sudo getfacl --absolute-names "${ISO_FILES}/boot/grub/grub.cfg" > "${TMP_SCRATCH_DIR}/acl_grub_cfg"
      sudo chmod +w "${ISO_FILES}"/boot/grub/grub.cfg
      sudo sed -i "/^submenu --hotkey=a.*/i menuentry --hotkey=p 'Auto with preseed' {\n\tset background_color=black\n\tlinux    \/install.amd\/vmlinuz vga=788 --- quiet\n\tinitrd   \/install.amd\/initrd.gz preseed\/file=\/cdrom\/preseed.cfg preseed\/file\/checksum=${PRESEED_MD5SUM}\n}" "${ISO_FILES}/boot/grub/grub.cfg"
      sudo setfacl --restore="${TMP_SCRATCH_DIR}/acl_grub_cfg"

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
      # find: File system loop detected; ‘./debian‘ is part of the same file system loop as ‘.’.
      # ```
      # Pruning of the directory didn't help, therefore move it temporarily out
      # of the way.
      mv ./debian "${TMP_SCRATCH_DIR}"
      find -L -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt

      sudo setfacl --restore="${TMP_SCRATCH_DIR}/acl_md5sum_txt"
      mv "${TMP_SCRATCH_DIR}/debian" .

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
      dd if="${ISO_ORIG}" bs=1 count=432 of="${MBR_TEMPLATE}"

      echo
      echo "## 2. Creating new iso..."
      # Warnings regarding symlinks for Joliet trees should be of no concern:
      # https://superuser.com/a/1598612
      xorriso -as mkisofs -r -V 'bullseye-preseed' \
         -cache-inodes -J -l \
         -isohybrid-mbr "${MBR_TEMPLATE}" \
         -partition_offset 16 \
         -c isolinux/boot.cat \
         -b isolinux/isolinux.bin \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
         -eltorito-alt-boot \
         -e boot/grub/efi.img \
            -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
         -o "${ISO_NEW}" \
         "${ISO_FILES}"

      popd > /dev/null # ${ISO_FILES}
   }


}
main "$@"
