#!/usr/bin/env bash

# ============================================================================
# Docker
# v1.0.0, 2021-09-20
# ----------------------------------------------------------------------------

echo
echo "##### Installing Docker..."
echo
echo "##### Apt update and upgrade, sudo required:"
sudo apt-get update && sudo apt-get -y upgrade

echo
echo "##### Download docker installer script and executing it..."
curl -sSL https://get.docker.com | bash -

echo
echo "##### Adding user to the docker group and enable docker daemon..."
sudo usermod -aG docker ${USER}

sudo systemctl enable docker
