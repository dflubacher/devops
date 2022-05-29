#!/usr/bin/env bash

# ============================================================================
# Rust
# ----------------------------------------------------------------------------

# Ensure apt is in non-interactive mode to avoid prompts.
export DEBIAN_FRONTEND=noninteractive

CURDIR=${PWD}

echo -e "\n### Installing Rust ..."
# https://www.rust-lang.org/tools/install
# https://doc.rust-lang.org/stable/book/ch01-01-installation.html
#
# Non-interactive installation.
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y

# - Update: `rustup update`
# - version: `rustc --version`