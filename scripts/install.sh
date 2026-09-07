#!/usr/bin/env bash
# Installs vsync: asks where obsidian-vault-sync lives, then adds it to
# PATH and sources vsync.sh automatically in your shell rc file.
set -u

marker_start="# >>> obsidian-vault-sync >>>"
marker_end="# <<< obsidian-vault-sync <<<"

default_repo_path="$(pwd)"
read -rp "Path to obsidian-vault-sync (where vsync.sh lives) [$default_repo_path]: " repo_path
repo_path="${repo_path:-$default_repo_path}"

if [ ! -d "$repo_path" ]; then
    echo "install: '$repo_path' does not exist." >&2
    exit 1
fi
repo_path="$(cd "$repo_path" && pwd)"

if [ ! -f "$repo_path/vsync.sh" ]; then
    echo "install: '$repo_path/vsync.sh' not found." >&2
    exit 1
fi

if [ -n "${ZSH_VERSION:-}" ] || [ "${SHELL##*/}" = "zsh" ]; then
    default_rc="$HOME/.zshrc"
else
    default_rc="$HOME/.bashrc"
fi
read -rp "Shell rc file to update [$default_rc]: " rc_file
rc_file="${rc_file:-$default_rc}"

touch "$rc_file"
if grep -qF "$marker_start" "$rc_file"; then
    echo "install: an existing obsidian-vault-sync block was found in $rc_file, replacing it..."
    sed -i.bak "/$marker_start/,/$marker_end/d" "$rc_file"
fi

{
    echo "$marker_start"
    echo "export PATH=\"$repo_path:\$PATH\""
    echo "source \"$repo_path/vsync.sh\""
    echo "$marker_end"
} >> "$rc_file"

echo "install: added to $rc_file"
echo "install: note that 'vsync' is a shell function, not a standalone binary — adding"
echo "install: $repo_path to PATH doesn't make 'vsync' runnable by itself; the 'source'"
echo "install: line is what actually makes the command available. PATH is added in case"
echo "install: you add other standalone scripts to this repo later."
echo
echo "install: run 'source $rc_file' (or open a new terminal) to start using 'vsync'."
echo "install: also make sure OBSIDIAN_VAULT_PATH is exported somewhere in $rc_file,"
echo "install: pointing at your Obsidian vault's path — vsync needs it and this"
echo "install: script does not set it for you."
