#!/usr/bin/env bash

# ============================================================================
# Bazelisk
# ----------------------------------------------------------------------------
# TODO: only works for amd64.

export DEBIAN_FRONTEND=noninteractive

echo
echo "# ######################################################################"
echo "# ### Installing Bazelisk                                            ###"
echo "# ######################################################################"
# https://docs.bazel.build/versions/master/updating-bazel.html
# (retrieved 2022-02-01).

echo
echo "##### Download the latest version of Bazelisk..."
# https://github.com/bazelbuild/bazelisk/releases
# curl -Lo /tmp/bazelisk-linux-amd64 https://github.com/bazelbuild/bazelisk/releases/download/v1.11.0/bazelisk-linux-amd64
curl -Lo /tmp/bazelisk-linux-amd64 https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64

echo
echo "##### Check if bazel is already installed..."
bazel_path=$(which bazel)
# If installed, this returns something like /usr/bin/bazel or
# /usr/local/bin/bazel.

# Step 3: in case bazel is installed, create backup of raw bazel
if ! [ -z "${bazel_path}" ]; then
    echo "### Bazel was found, backing it up."
    sudo mv "${bazel_path}" /usr/bin/bazel_orig
else
    echo "### Bazel not found, installing Bazelisk in place."
    bazel_path="/usr/bin/bazel"
fi

echo
echo "##### Configuring Bazelisk..."
sudo mv /tmp/bazelisk-linux-amd64 "${bazel_path}"
# make it executable
sudo chmod 755 "${bazel_path}"
# adapt ownership
sudo chown root:root "${bazel_path}"

# If you get signature issues like this:
#  > An error occurred during the signature verification. The repository is not
#  > updated and the previous index files will be used.
# Do the following:
#  $ curl https://bazel.build/bazel-release.pub.gpg | sudo apt-key add -
#  $ sudo apt-get update
#  > https://stackoverflow.com/a/50589259


# ============================================================================
# Buildifier
# Formatting of BUILD files.
# https://github.com/bazelbuild/buildtools
# ----------------------------------------------------------------------------
echo
echo "##### Downloading and configuring Buildifier..."
# curl -Lo /tmp/buildifier "https://github.com/bazelbuild/buildtools/releases/download/4.2.5/buildifier-linux-amd64"
curl -Lo /tmp/buildifier-linux-amd64 "https://github.com/bazelbuild/buildtools/releases/latest/download/buildifier-linux-amd64"

sudo chmod +x /tmp/buildifier-linux-amd64
sudo chown root:root /tmp/buildifier-linux-amd64

sudo mv /tmp/buildifier-linux-amd64 /usr/local/bin/buildifier

echo "##### Done!"
