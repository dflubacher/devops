#!/usr/bin/env bash

# =============================================================================
# Script to run as user at first login. This is useful for stuff that should be
# run as user (before Ansible can take over)
# -----------------------------------------------------------------------------

# Install poetry. After this step, this repository can be downloaded/copied,
# and `poetry update` can be run in the root of this repo. This sets up Ansible
# and a playbook can be used to finish the installation.

# XDG autostart doesn't open a terminal, only once `gnome-terminal` is called.
# Put a dialog in there.
cat << EOF > /tmp/finishing_start.sh
    echo "# ######################################################################"
    echo "# Finishing initial installation, sudo required."
    echo "# ======================================================================"
    echo ""
EOF
cat << EOF > /tmp/finishing_end.sh
    echo "# ======================================================================"
    echo "# Please logout and login again after the Ubuntu initial setup."
    echo "# ======================================================================"
    echo ""
    sleep 5
    # TODO: Somehow waiting on user input doesn't work in combination with
    #       `gnome-terminal`.
    # read -n 1 -s -r -p "# Press any key to continue ..."
EOF
chmod a+x /tmp/finishing_start.sh
chmod a+x /tmp/finishing_end.sh

# Check if poetry installation script exists.
if ( command -v install_poetry.sh > /dev/null ); then
    gnome-terminal --wait -- /bin/sh -c '/tmp/finishing_start.sh; install_poetry.sh; /tmp/finishing_end.sh'
else
    echo "Error: install_poetry.sh not found."
fi

echo
echo "##### Calling default gnome initial setup..."
# Resume with default first login script provided by Ubuntu Desktop.
/usr/libexec/gnome-initial-setup-orig --existing-user
