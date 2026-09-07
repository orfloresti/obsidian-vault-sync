# obsidian.sh
#
# `obsidian` command to sync an Obsidian vault via git from any terminal,
# without having to cd into the vault folder.
#
# Requires: export OBSIDIAN_VAULT_PATH=/path/to/your/vault  (before sourcing this file)
#
# `obsidian update` figures out where this file itself lives (wherever you
# cloned obsidian-vault-sync) automatically, no config needed. Only set
# OBSIDIAN_SYNC_PATH if that detection doesn't work for your setup.
#
# Usage:
#   obsidian pull    - pull the latest changes from the remote (stashes any
#                       uncommitted local changes first and reapplies them after)
#   obsidian push    - add + commit (auto-generated message) + pull + push
#   obsidian sync    - pull, then push, in a single command
#   obsidian update  - update this tool itself (pulls obsidian-vault-sync)
#   obsidian help    - show this usage message

obsidian() {
    case "$1" in
        help | -h | --help)
            _obsidian_help
            return 0
            ;;
        update)
            _obsidian_update
            return $?
            ;;
    esac

    if [ -z "$OBSIDIAN_VAULT_PATH" ]; then
        echo "obsidian: OBSIDIAN_VAULT_PATH is not set. Add 'export OBSIDIAN_VAULT_PATH=/path/to/your/vault' to your .bashrc/.zshrc" >&2
        return 1
    fi

    if [ ! -d "$OBSIDIAN_VAULT_PATH/.git" ]; then
        echo "obsidian: '$OBSIDIAN_VAULT_PATH' is not a git repository" >&2
        return 1
    fi

    case "$1" in
        pull)
            _obsidian_pull
            ;;
        push)
            _obsidian_push
            ;;
        sync)
            _obsidian_pull || return 1
            _obsidian_push
            ;;
        *)
            _obsidian_help >&2
            return 1
            ;;
    esac
}

# Detect the directory this file was sourced from, so `obsidian update`
# works without any extra configuration. BASH_SOURCE covers bash; zsh
# doesn't set $0 to the sourced file, so it needs its own idiom.
if [ -n "${BASH_SOURCE:-}" ]; then
    _obsidian_self="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    _obsidian_self="${(%):-%N}"
fi
if [ -n "${_obsidian_self:-}" ]; then
    OBSIDIAN_SYNC_DIR="$(cd "$(dirname "$_obsidian_self")" && pwd)"
fi
unset _obsidian_self

_obsidian_help() {
    cat <<'EOF'
Usage: obsidian <command>

Commands:
  pull    Pull the latest changes from the remote (stashes any uncommitted
          local changes first and reapplies them after)
  push    Add + commit (auto-generated message) + pull + push
  sync    Pull, then push, in a single command
  update  Update this tool itself (pulls obsidian-vault-sync)
  help    Show this message

Requires: export OBSIDIAN_VAULT_PATH=/path/to/your/vault
'obsidian update' auto-detects where obsidian-vault-sync is cloned; set
OBSIDIAN_SYNC_PATH only if that detection fails for your setup.
EOF
}

_obsidian_update() {
    local sync_dir="${OBSIDIAN_SYNC_PATH:-${OBSIDIAN_SYNC_DIR:-$HOME/.obsidian-vault-sync}}"

    if [ ! -d "$sync_dir/.git" ]; then
        echo "obsidian: '$sync_dir' is not a git repository. Set OBSIDIAN_SYNC_PATH to where you cloned obsidian-vault-sync." >&2
        return 1
    fi

    echo "obsidian: updating obsidian-vault-sync..."
    if ! git -C "$sync_dir" pull --no-edit --no-rebase; then
        echo "obsidian: conflict while updating. Resolve it manually in $sync_dir." >&2
        return 1
    fi

    echo "obsidian: done. Open a new terminal (or re-source obsidian.sh) to load the update."
}

# Explicit --no-rebase so this doesn't depend on the device's git config
# (some git setups demand "reconcile divergent branches" if pull.rebase/
# pull.ff aren't configured). Any uncommitted local changes are stashed
# before pulling and reapplied after, so a pull never gets blocked or
# silently loses work.
_obsidian_pull() {
    local vault="$OBSIDIAN_VAULT_PATH"
    local stashed=0

    if ! git -C "$vault" diff --quiet || ! git -C "$vault" diff --cached --quiet; then
        echo "obsidian: stashing uncommitted local changes before pulling..."
        git -C "$vault" stash push -u -m "obsidian pull: uncommitted changes" || return 1
        stashed=1
    fi

    if ! git -C "$vault" pull --no-edit --no-rebase; then
        echo "obsidian: conflict while pulling." >&2
        if [ "$stashed" -eq 1 ]; then
            echo "obsidian: your local changes are safe in a git stash. Resolve the conflict in $vault, then run 'git stash pop' there." >&2
        fi
        return 1
    fi

    if [ "$stashed" -eq 1 ]; then
        if ! git -C "$vault" stash pop; then
            echo "obsidian: conflict while reapplying your local changes (git stash pop). Resolve it manually in $vault." >&2
            return 1
        fi
    fi
}

_obsidian_push() {
    local vault="$OBSIDIAN_VAULT_PATH"

    git -C "$vault" add -A

    if ! git -C "$vault" diff --cached --quiet; then
        local files count summary
        files=$(git -C "$vault" diff --cached --name-only)
        count=$(printf '%s\n' "$files" | wc -l | tr -d ' ')

        if [ "$count" -le 5 ]; then
            summary=$(printf '%s\n' "$files" | paste -sd, - | sed 's/,/, /g')
        else
            summary="$count files changed"
        fi

        git -C "$vault" commit -m "sync: $summary" || return 1
    else
        echo "obsidian: no local changes to commit"
    fi

    echo "obsidian: syncing with the remote..."
    if ! git -C "$vault" pull --no-edit --no-rebase; then
        echo "obsidian: conflict while pulling. Resolve it manually in $vault and run 'obsidian push' again." >&2
        return 1
    fi

    git -C "$vault" push
}
