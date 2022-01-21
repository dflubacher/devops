#!/usr/bin/env bash

# =============================================================================
# Poetry
# v0.1.0 2021-11-25
# -----------------------------------------------------------------------------

# Python 3 should be installed by default on Debian 11, Ubuntu >18.04 and Linux
# Mint 20.

echo
echo "##### Installing pip for Python 3 with apt, sudo required:"
# TODO: python3.8-venv is required, but there should be a solution:
# https://github.com/python-poetry/poetry/issues/197
# python3-venv for focal has a required dependency for python3.8-venv.
# If the Python version was upgraded from the default, this might not work.
sudo apt-get update && sudo apt-get -y install --no-install-recommends python3-pip python3-venv

# Upgrade pip3, https://github.com/pypa/pip/issues/5599.
python3 -m pip install --user --upgrade pip

# Enable bash autocompletion for pip.
python3 -m pip completion --bash >> ${HOME}/.bashrc


# =============================================================================
# Poetry installation according:
# https://python-poetry.org/docs/master/#installation

echo
echo "##### Installing Poetry..."
pushd /tmp
curl -sSL https://install.python-poetry.org | python3 -

popd

# Either logout/login or source ${HOME}/.profile to set up poetry in the
# current shell.
