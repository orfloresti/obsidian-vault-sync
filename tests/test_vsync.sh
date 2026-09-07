#!/usr/bin/env bash
# Regression tests for vsync.sh — run with: make test  (or: bash tests/test_vsync.sh)
#
# Formalizes the scenarios manually verified while building this tool:
# help/usage, no-args = sync, pull stashing uncommitted changes (with and
# without a real conflict), push committing + surviving divergent branches
# without relying on the device's git config, and update/version/auto-detect.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VSYNC_SH="$SCRIPT_DIR/../vsync.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  ok   - $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL - $1"; }

assert_contains() {
    # assert_contains "description" "haystack" "needle"
    case "$2" in
        *"$3"*) pass "$1" ;;
        *) fail "$1 (expected output to contain: $3)" ;;
    esac
}

assert_not_contains() {
    case "$2" in
        *"$3"*) fail "$1 (expected output to NOT contain: $3)" ;;
        *) pass "$1" ;;
    esac
}

assert_exit() {
    # assert_exit "description" expected_code actual_code
    if [ "$2" -eq "$3" ]; then
        pass "$1"
    else
        fail "$1 (expected exit $2, got $3)"
    fi
}

# Creates $1/remote.git and $1/local, with one commit pushed to main.
new_repo_pair() {
    local base="$1"
    git init --bare -q "$base/remote.git"
    git clone -q "$base/remote.git" "$base/local"
    (
        cd "$base/local" || exit 1
        git checkout -q -b main 2>/dev/null || git branch -m main
        git config user.email test@test.com
        git config user.name test
        echo "seed" > seed.md
        git add seed.md
        git commit -q -m init
        git push -q -u origin main
    )
}

# Clones $1/remote.git into $2 and makes sure it's actually on a `main`
# branch tracking origin/main — a fresh `git init --bare` defaults its HEAD
# symref to `master` regardless of which branch commits land on, so a plain
# `git clone` right after `new_repo_pair` can silently check out an empty,
# unrelated `master` instead of the `main` that actually has history.
clone_as_main() {
    local remote="$1" dest="$2"
    git clone -q "$remote" "$dest" 2>/dev/null
    git -C "$dest" checkout -q -B main origin/main
}

# Resets all vsync state between tests so nothing leaks across cases.
reset_env() {
    unset -f vsync _vsync_help _vsync_pull _vsync_push _vsync_update _vsync_version _vsync_sync_dir 2>/dev/null
    unset OBSIDIAN_VAULT_PATH VSYNC_PATH VSYNC_DIR
    # shellcheck disable=SC1090
    source "$VSYNC_SH"
}

echo "=== vsync.sh test suite ==="

### help / usage ###################################################
reset_env
out=$(vsync help 2>&1); code=$?
assert_exit "vsync help exits 0" 0 "$code"
assert_contains "vsync help shows usage" "$out" "Usage: vsync"

reset_env
out=$(vsync bogus 2>&1); code=$?
assert_exit "unknown subcommand exits 1" 1 "$code"
assert_contains "unknown subcommand shows usage" "$out" "Usage: vsync"

### missing / invalid OBSIDIAN_VAULT_PATH ##########################
reset_env
unset OBSIDIAN_VAULT_PATH
out=$(vsync 2>&1); code=$?
assert_exit "no OBSIDIAN_VAULT_PATH exits 1" 1 "$code"
assert_contains "no OBSIDIAN_VAULT_PATH gives a clear error" "$out" "OBSIDIAN_VAULT_PATH is not set"

reset_env
export OBSIDIAN_VAULT_PATH="$WORK/not-a-repo"
mkdir -p "$OBSIDIAN_VAULT_PATH"
out=$(vsync pull 2>&1); code=$?
assert_exit "non-git vault path exits 1" 1 "$code"
assert_contains "non-git vault path gives a clear error" "$out" "is not a git repository"

### push: nothing to commit still succeeds #########################
reset_env
REPO="$WORK/push_clean"; mkdir -p "$REPO"; new_repo_pair "$REPO"
export OBSIDIAN_VAULT_PATH="$REPO/local"
out=$(vsync push 2>&1); code=$?
assert_exit "push with no local changes exits 0" 0 "$code"
assert_contains "push with no local changes says so" "$out" "no local changes to commit"

### push: commits and pushes local changes #########################
reset_env
REPO="$WORK/push_changes"; mkdir -p "$REPO"; new_repo_pair "$REPO"
export OBSIDIAN_VAULT_PATH="$REPO/local"
echo "edit" >> "$OBSIDIAN_VAULT_PATH/seed.md"
out=$(vsync push 2>&1); code=$?
assert_exit "push with local changes exits 0" 0 "$code"
assert_contains "push commit message lists the changed file" "$out" "sync: seed.md"
remote_log=$(git -C "$REPO/remote.git" log --oneline -1 main)
assert_contains "the commit actually reached the remote" "$remote_log" "sync: seed.md"

### push: survives divergent branches without relying on device git config
reset_env
REPO="$WORK/push_divergent"; mkdir -p "$REPO"; new_repo_pair "$REPO"
clone_as_main "$REPO/remote.git" "$REPO/other"
(
    cd "$REPO/other" || exit 1
    git config user.email o@test.com; git config user.name other
    echo "from other device" >> seed.md
    git add seed.md && git commit -q -m "other device"
    git push -q origin main
)
export OBSIDIAN_VAULT_PATH="$REPO/local"
echo "from this device" >> "$OBSIDIAN_VAULT_PATH/notes.md"
out=$(vsync push 2>&1); code=$?
assert_exit "push merges divergent branches and succeeds" 0 "$code"
assert_not_contains "push never asks to reconcile divergent branches" "$out" "Need to specify how to reconcile"

### pull: stashes uncommitted local changes, no real conflict ######
reset_env
REPO="$WORK/pull_clean"; mkdir -p "$REPO"; new_repo_pair "$REPO"
clone_as_main "$REPO/remote.git" "$REPO/other"
(
    cd "$REPO/other" || exit 1
    git config user.email o@test.com; git config user.name other
    echo "remote change" > new-from-remote.md
    git add new-from-remote.md && git commit -q -m "remote change"
    git push -q origin main
)
export OBSIDIAN_VAULT_PATH="$REPO/local"
echo "unrelated local edit" > "$OBSIDIAN_VAULT_PATH/local-only.md"
out=$(vsync pull 2>&1); code=$?
assert_exit "pull with unrelated uncommitted changes exits 0" 0 "$code"
assert_contains "pull stashes before pulling" "$out" "stashing uncommitted"
[ -f "$OBSIDIAN_VAULT_PATH/new-from-remote.md" ] \
    && pass "pull brought the remote change" \
    || fail "pull brought the remote change"
[ -f "$OBSIDIAN_VAULT_PATH/local-only.md" ] \
    && pass "pull preserved the uncommitted local change" \
    || fail "pull preserved the uncommitted local change"

### pull: real conflict surfaces cleanly, nothing lost ##############
reset_env
REPO="$WORK/pull_conflict"; mkdir -p "$REPO"; new_repo_pair "$REPO"
clone_as_main "$REPO/remote.git" "$REPO/other"
(
    cd "$REPO/other" || exit 1
    git config user.email o@test.com; git config user.name other
    echo "remote edit" >> seed.md
    git add seed.md && git commit -q -m "remote edit"
    git push -q origin main
)
export OBSIDIAN_VAULT_PATH="$REPO/local"
echo "conflicting local edit" >> "$OBSIDIAN_VAULT_PATH/seed.md"
out=$(vsync pull 2>&1); code=$?
assert_exit "pull with a real conflict exits 1" 1 "$code"
assert_contains "pull reports the conflict" "$out" "conflict"
stash_list=$(git -C "$OBSIDIAN_VAULT_PATH" stash list)
assert_contains "the local edit is safe in a stash, not lost" "$stash_list" "uncommitted changes"

### sync (no args) = pull then push #################################
reset_env
REPO="$WORK/sync_default"; mkdir -p "$REPO"; new_repo_pair "$REPO"
export OBSIDIAN_VAULT_PATH="$REPO/local"
echo "edit" >> "$OBSIDIAN_VAULT_PATH/seed.md"
out=$(vsync 2>&1); code=$?
assert_exit "bare vsync (sync) exits 0" 0 "$code"
assert_contains "bare vsync commits like push does" "$out" "sync: seed.md"
remote_log=$(git -C "$REPO/remote.git" log --oneline -1 main)
assert_contains "bare vsync's commit reached the remote" "$remote_log" "sync: seed.md"

### update + version + auto-detected VSYNC_DIR ######################
reset_env
TOOLREPO="$WORK/toolrepo"; mkdir -p "$TOOLREPO"
git init --bare -q "$TOOLREPO/remote.git"
git clone -q "$TOOLREPO/remote.git" "$TOOLREPO/device"
cp "$VSYNC_SH" "$TOOLREPO/device/vsync.sh"
(
    cd "$TOOLREPO/device" || exit 1
    git checkout -q -b main 2>/dev/null || git branch -m main
    git config user.email t@test.com; git config user.name t
    git add vsync.sh && git commit -q -m "v1"
    git push -q -u origin main
)
unset -f vsync _vsync_help _vsync_pull _vsync_push _vsync_update _vsync_version _vsync_sync_dir 2>/dev/null
unset OBSIDIAN_VAULT_PATH VSYNC_PATH VSYNC_DIR
# shellcheck disable=SC1090
source "$TOOLREPO/device/vsync.sh"
assert_contains "sourcing auto-detects VSYNC_DIR" "$VSYNC_DIR" "$TOOLREPO/device"

expected_hash=$(git -C "$TOOLREPO/device" rev-parse --short HEAD)
got_hash=$(vsync version)
assert_contains "vsync version prints the current commit hash" "$got_hash" "$expected_hash"

out=$(vsync update 2>&1); code=$?
assert_exit "vsync update exits 0 when already current" 0 "$code"
assert_contains "vsync update reports success" "$out" "Already up to date"

echo
echo "=== $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
