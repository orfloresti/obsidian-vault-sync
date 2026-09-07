# vsync.sh
#
# `vsync` command to sync an Obsidian vault via git from any terminal,
# without having to cd into the vault folder.
#
# Requires: export OBSIDIAN_VAULT_PATH=/path/to/your/vault  (before sourcing this file)
#
# `vsync update` figures out where this file itself lives (wherever you
# cloned obsidian-vault-sync) automatically, no config needed. Only set
# VSYNC_PATH if that detection doesn't work for your setup.
#
# Usage:
#   vsync            - pull, then push, in a single command (the common case)
#   vsync pull       - pull the latest changes from the remote (stashes any
#                       uncommitted local changes first and reapplies them after)
#   vsync push       - add + commit (auto-generated message) + pull + push
#   vsync update     - update this tool itself (pulls obsidian-vault-sync)
#   vsync version    - print the commit hash of this tool (to compare devices)
#   vsync help       - show this usage message

vsync() {
    case "${1:-}" in
        help | -h | --help)
            _vsync_help
            return 0
            ;;
        update)
            _vsync_update
            return $?
            ;;
        version)
            _vsync_version
            return $?
            ;;
        "" | pull | push)
            : # valid, handled below once OBSIDIAN_VAULT_PATH is checked
            ;;
        *)
            _vsync_help >&2
            return 1
            ;;
    esac

    if [ -z "${OBSIDIAN_VAULT_PATH:-}" ]; then
        echo "vsync: OBSIDIAN_VAULT_PATH is not set. Add 'export OBSIDIAN_VAULT_PATH=/path/to/your/vault' to your .bashrc/.zshrc" >&2
        return 1
    fi

    if [ ! -d "$OBSIDIAN_VAULT_PATH/.git" ]; then
        echo "vsync: '$OBSIDIAN_VAULT_PATH' is not a git repository" >&2
        return 1
    fi

    case "${1:-}" in
        "")
            _vsync_pull || return 1
            _vsync_push
            ;;
        pull)
            _vsync_pull
            ;;
        push)
            _vsync_push
            ;;
    esac
}

# Detect the directory this file was sourced from, so `vsync update` works
# without any extra configuration. BASH_SOURCE covers bash; zsh doesn't set
# $0 to the sourced file, so it needs its own idiom.
if [ -n "${BASH_SOURCE:-}" ]; then
    _vsync_self="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    _vsync_self="${(%):-%N}"
fi
if [ -n "${_vsync_self:-}" ]; then
    VSYNC_DIR="$(cd "$(dirname "$_vsync_self")" && pwd)"
fi
unset _vsync_self

_vsync_help() {
    cat <<'EOF'
Usage: vsync [command]

Commands:
  (none)   Pull, then push, in a single command — the common case
  pull     Pull the latest changes from the remote (stashes any uncommitted
           local changes first and reapplies them after)
  push     Add + commit (auto-generated message) + pull + push
  update   Update this tool itself (pulls obsidian-vault-sync)
  version  Print the commit hash of this tool (to compare devices)
  help     Show this message

Requires: export OBSIDIAN_VAULT_PATH=/path/to/your/vault
'vsync update'/'vsync version' auto-detect where obsidian-vault-sync is
cloned; set VSYNC_PATH only if that detection fails for your setup.
EOF
}

# Resolves and validates the obsidian-vault-sync repo location, shared by
# `vsync update` and `vsync version`. Prints the path on success.
_vsync_sync_dir() {
    local dir="${VSYNC_PATH:-${VSYNC_DIR:-$HOME/.obsidian-vault-sync}}"

    if [ ! -d "$dir/.git" ]; then
        echo "vsync: '$dir' is not a git repository. Set VSYNC_PATH to where you cloned obsidian-vault-sync." >&2
        return 1
    fi

    printf '%s\n' "$dir"
}

_vsync_update() {
    local sync_dir
    sync_dir=$(_vsync_sync_dir) || return 1

    echo "vsync: updating obsidian-vault-sync..."
    if ! git -C "$sync_dir" pull --no-edit --no-rebase; then
        echo "vsync: conflict while updating. Resolve it manually in $sync_dir." >&2
        return 1
    fi

    if [ -f "$sync_dir/vsync.sh" ]; then
        source "$sync_dir/vsync.sh"
        echo "vsync: done and reloaded."
    else
        echo "vsync: done, but couldn't find $sync_dir/vsync.sh to reload automatically. Open a new terminal to pick up the update." >&2
    fi
}

_vsync_version() {
    local sync_dir
    sync_dir=$(_vsync_sync_dir) || return 1

    git -C "$sync_dir" rev-parse --short HEAD
}

# Explicit --no-rebase so this doesn't depend on the device's git config
# (some git setups demand "reconcile divergent branches" if pull.rebase/
# pull.ff aren't configured). Any uncommitted local changes — including new,
# untracked files (e.g. a note you just created) — are stashed before
# pulling and reapplied after, so a pull never gets blocked or silently
# loses work. `git status --porcelain` is used instead of `git diff
# --quiet`/`--cached` because those two miss untracked files entirely.
_vsync_pull() {
    local vault="$OBSIDIAN_VAULT_PATH"
    local stashed=0

    if [ -n "$(git -C "$vault" status --porcelain)" ]; then
        echo "vsync: stashing uncommitted local changes before pulling..."
        git -C "$vault" stash push -u -m "vsync pull: uncommitted changes" || return 1
        stashed=1
    fi

    if ! git -C "$vault" pull --no-edit --no-rebase; then
        echo "vsync: conflict while pulling." >&2
        if [ "$stashed" -eq 1 ]; then
            echo "vsync: your local changes are safe in a git stash. Resolve the conflict in $vault, then run 'git stash pop' there." >&2
        fi
        return 1
    fi

    if [ "$stashed" -eq 1 ]; then
        if ! git -C "$vault" stash pop; then
            echo "vsync: conflict while reapplying your local changes (git stash pop). Resolve it manually in $vault." >&2
            return 1
        fi
    fi
}

_vsync_push() {
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
        echo "vsync: no local changes to commit"
    fi

    echo "vsync: syncing with the remote..."
    if ! git -C "$vault" pull --no-edit --no-rebase; then
        echo "vsync: conflict while pulling. Resolve it manually in $vault and run 'vsync push' again." >&2
        return 1
    fi

    git -C "$vault" push
}
