#!/usr/bin/env bash

# =============================================================================
# Autocomplete using bash history
# src: https://unix.stackexchange.com/a/20830
# -----------------------------------------------------------------------------
# Key bindings, up/down arrow searches through history
if ! ( [ -f "${HOME}/.inputrc" ] && grep -q 'Autocomplete: Key bindings' ${HOME}/.inputrc ); then
    tee -a ${HOME}/.inputrc >/dev/null <<-'EOF'
    # -----------------------------------------------------------------------------
    # Autocomplete: Key bindings, up/down arrow searches through history
    # -----------------------------------------------------------------------------
    "\e[A": history-search-backward
    "\e[B": history-search-forward
    "\eOA": history-search-backward
    "\eOB": history-search-forward
    # Autocomplete ----------------------------------------------------------------
EOF
fi