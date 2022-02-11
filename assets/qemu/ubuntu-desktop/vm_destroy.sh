#!/usr/bin/env bash

# optional positional arguments:
# 1 - vm_create_file: absolute path with environment variables for the iso
#                     (default: ./vm_create.sh relative to script directory)

declare -r SCRIPT_DIR=$(dirname "$0") > /dev/null
VARS_FILE=${1:-"./vm_create.sh"}


pushd ${SCRIPT_DIR} > /dev/null

[ -f $(realpath ${VARS_FILE}) ] || { echo "${VARS_FILE} not found!"; exit; }

set +a
. ${VARS_FILE}
set -a

virsh undefine --remove-all-storage "${NAME}"

popd > /dev/null