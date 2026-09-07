#!/usr/bin/env bash
# Installs vsync: detects where obsidian-vault-sync itself lives (no need
# to type it), asks for your Obsidian vault's path, then adds PATH +
# OBSIDIAN_VAULT_PATH + the vsync.sh source line to your shell rc file.
set -u

marker_start="# >>> obsidian-vault-sync >>>"
marker_end="# <<< obsidian-vault-sync <<<"

# Derived from this script's own location, not `pwd` — works no matter
# where `make install` was invoked from.
repo_path="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$repo_path/vsync.sh" ]; then
    echo "install: '$repo_path/vsync.sh' not found — is this script still inside the obsidian-vault-sync repo?" >&2
    exit 1
fi
echo "install: obsidian-vault-sync detected at $repo_path"

default_vault="${OBSIDIAN_VAULT_PATH:-$HOME/obsidian-vault}"
read -rp "Path to your Obsidian vault [$default_vault]: " vault_path
vault_path="${vault_path:-$default_vault}"
# Expand a leading ~ (read doesn't expand it, or $VARS, the way a shell would)
vault_path="${vault_path/#\~/$HOME}"

if [ ! -d "$vault_path" ]; then
    echo "install: warning — '$vault_path' doesn't exist yet. Using it anyway; make sure to clone your vault there." >&2
else
    vault_path="$(cd "$vault_path" && pwd)"
fi

if [ -n "${ZSH_VERSION:-}" ] || [ "${SHELL##*/}" = "zsh" ]; then
    default_rc="$HOME/.zshrc"
else
    default_rc="$HOME/.bashrc"
fi
read -rp "Shell rc file to update [$default_rc]: " rc_file
rc_file="${rc_file:-$default_rc}"
rc_file="${rc_file/#\~/$HOME}"

touch "$rc_file"
if grep -qF "$marker_start" "$rc_file"; then
    echo "install: an existing obsidian-vault-sync block was found in $rc_file, replacing it..."
    sed -i.bak "/$marker_start/,/$marker_end/d" "$rc_file"
fi

{
    echo "$marker_start"
    echo "export OBSIDIAN_VAULT_PATH=\"$vault_path\""
    echo "export PATH=\"$repo_path:\$PATH\""
    echo "source \"$repo_path/vsync.sh\""
    echo "$marker_end"
} >> "$rc_file"

echo "install: added to $rc_file"
echo "install: run 'source $rc_file' (or open a new terminal) to start using 'vsync'."
