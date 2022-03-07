#!/usr/bin/env bash

# ============================================================================
# balena etcher
# ----------------------------------------------------------------------------
# TODO: only works for amd64.

export DEBIAN_FRONTEND=noninteractive

echo
echo "# ######################################################################"
echo "# ### Installing balena etcher                                       ###"
echo "# ######################################################################"
# https://www.omgubuntu.co.uk/2017/05/how-to-install-etcher-on-ubuntu
# (retrieved 2022-03-07).

echo
echo "##### Install apt repository and signing key..."
# TODO: apt-key doesn't have a `deprecated` note in the man page in
#       Ubuntu 20.04. What is the right way to deal with keys?

# This key seems to be outdated.
# gpg --no-default-keyring --keyring /tmp/balena-io.gpg --keyserver keyserver.ubuntu.com --recv-keys 379CE192D401AB61

# https://askubuntu.com/a/1307181
# with key from here:
# https://github.com/balena-io/etcher/issues/3084#issuecomment-834486482
pushd /tmp
curl -Lo /tmp/balena-io.key https://dl.cloudsmith.io/public/balena/etcher/gpg.70528471AFF9A051.key

gpg --no-default-keyring --keyring /tmp/temp-keyring.gpg --import /tmp/balena-io.key
gpg --no-default-keyring --keyring ./temp-keyring.gpg --export --output balena-io.gpg

[ -d /usr/local/share/keyrings ] || sudo mkdir -p /usr/local/share/keyrings

sudo mv /tmp/balena-io.gpg /usr/local/share/keyrings/
sudo rm /tmp/temp-keyring.gpg

echo
echo "##### Update sources list for balena etcher..."
sudo tee /etc/apt/sources.list.d/balena-etcher.list > /dev/null <<'EOF'
deb [signed-by=/usr/local/share/keyrings/balena-io.gpg] https://dl.cloudsmith.io/public/balena/etcher/deb/ubuntu focal main

deb-src [signed-by=/usr/local/share/keyrings/balena-io.gpg] https://dl.cloudsmith.io/public/balena/etcher/deb/ubuntu focal main
EOF

echo
echo "##### Installing balena etcher..."
sudo apt-get update && sudo apt-get -y install balena-etcher-electron

popd
echo "##### Done!"

# Script found here:
# https://forums.balena.io/t/balenaetcher-repository-not-found/308436
# curl -1sLf 'https://dl.cloudsmith.io/public/balena/etcher/setup.deb.sh' | sudo -E bash