#!/bin/bash

# ============================================================================
# balena etcher
# ----------------------------------------------------------------------------
# TODO: only works for amd64.
# NOTE: balena etcher is no longer hosted on cloudsmith.io.

export DEBIAN_FRONTEND=noninteractive

echo
echo "# ######################################################################"
echo "# ### Installing balena etcher                                       ###"
echo "# ######################################################################"

echo
echo "##### Download package from github..."
installer_url=$(curl -s https://api.github.com/repos/balena-io/etcher/releases/latest | grep browser_download_url | cut -d\" -f4 | egrep 'amd64+.deb$')
installer_path="/tmp/$(basename ${installer_url})"

echo $installer_path

curl -Lo ${installer_path} ${installer_url}

echo
echo "##### Installing balena etcher..."
sudo apt-get update && sudo apt-get -y install ${installer_path}

echo "##### Done!"
