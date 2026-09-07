#!/usr/bin/env bash
# Removes the obsidian-vault-sync block installed by scripts/install.sh
# from ~/.bashrc and ~/.zshrc (whichever has it). Does not delete the
# cloned repo or touch your Obsidian vault.
set -u

marker_start="# >>> obsidian-vault-sync >>>"
marker_end="# <<< obsidian-vault-sync <<<"

removed=0
for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc_file" ] && grep -qF "$marker_start" "$rc_file"; then
        sed -i.bak "/$marker_start/,/$marker_end/d" "$rc_file"
        echo "uninstall: removed from $rc_file (backup saved as $rc_file.bak)"
        removed=1
    fi
done

if [ "$removed" -eq 0 ]; then
    echo "uninstall: no obsidian-vault-sync block found in ~/.bashrc or ~/.zshrc"
    exit 0
fi

echo "uninstall: open a new terminal (or re-source your rc file) for the change to take effect."
echo "uninstall: this only removes it from your shell config — it does not delete the"
echo "uninstall: cloned repo or your Obsidian vault."
