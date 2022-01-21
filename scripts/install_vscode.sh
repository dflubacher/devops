#!/usr/bin/env bash

# =============================================================================
# VS Code
# v0.1.0 2021-10-20
# -----------------------------------------------------------------------------

# https://code.visualstudio.com/docs/setup/linux
# Manual procedure:

pushd /tmp
echo
echo "##### Install apt repository and signing key..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/

echo
echo "### Enable auto-updating using the system's package manager..."
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg

echo
echo "### Update the package cache and install the package..."
sudo apt-get install -y apt-transport-https
sudo apt-get update
sudo apt-get install -y code # or code-insiders


echo
echo "### Installing extensions..."
declare -a EXTENSION_IDS=(  "ms-vscode.cpptools" \
                            "ms-python.python" \
                            "ms-python.vscode-pylance" \
                            "ms-vscode-remote.vscode-remote-extensionpack")

for ext in "${EXTENSION_IDS[@]}"
do
    echo "Installing ${ext}..."
    code --install-extension ${ext}
done

popd
