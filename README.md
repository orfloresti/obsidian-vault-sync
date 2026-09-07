# obsidian-vault-sync

`vsync` command to sync an Obsidian vault via git from any terminal, without
having to cd into the vault folder.

## Commands

- `vsync` (no arguments) — runs `pull` and then `push` in a single command.
  This is the common case, so it's the default.
- `vsync pull` — pulls the latest changes from the remote.
- `vsync push` — adds and commits local changes (with an auto-generated
  message listing the changed files), runs `pull` first so the push isn't
  rejected if another device pushed changes first, then runs `push`.
- `vsync update` — updates this tool itself (pulls the `obsidian-vault-sync`
  repo). It auto-detects where you sourced `vsync.sh` from, no matter where
  you cloned it — no configuration needed. Only set `VSYNC_PATH` if that
  detection fails for your setup. It reloads itself when done — no need to
  open a new terminal.
- `vsync version` — prints just the short commit hash of `obsidian-vault-sync`
  (same path detection as `update`). Useful to compare across devices and
  confirm they're all running the same version.
- `vsync help` (or `-h` / `--help`) — shows usage help.

If `vsync push` (or `vsync pull`) hits a conflict while pulling, it stops
and tells you to resolve it manually in the vault folder — it never tries
to resolve it on its own.

**Recommendation:** run `vsync` on its own before you start editing notes on
a device. That way you start from the latest remote state and lower the
risk of your edits colliding (merge conflict) with changes made on another
device in the meantime.

## Installation (on each device)

1. Clone this repo anywhere:

   ```bash
   git clone https://github.com/orfloresti/obsidian-vault-sync.git ~/.obsidian-vault-sync
   ```

2. Run the installer:

   ```bash
   cd ~/.obsidian-vault-sync
   make install
   ```

   It auto-detects where this repo itself lives (from wherever the script
   is running) — you don't need to type that path. It will ask for your
   Obsidian vault's path and which shell rc file to update (`~/.bashrc` by
   default, or `~/.zshrc` if your shell is zsh). It adds a marker-delimited
   block to that file with `OBSIDIAN_VAULT_PATH`, the repo's path added to
   `PATH`, and the `source` of `vsync.sh`. Running it again replaces the
   block instead of duplicating it.

   `vsync` is a shell function, not a binary — what actually makes it
   available is the `source` line, not `PATH` (that's added in case you add
   other standalone scripts to this repo later).

3. Open a new terminal (or run `source ~/.bashrc`) and try it:

   ```bash
   vsync
   ```

Each device (PC, Termux, tablet) only needs `OBSIDIAN_VAULT_PATH` pointing
at its own clone of `obsidian-vault` — the script (`vsync.sh`) is the same
on all of them.

To remove it from a device:
```bash
make uninstall
```
It looks for the block in `~/.bashrc` and `~/.zshrc` and removes it from
wherever it finds it (saving a `.bak` copy first). It doesn't delete the
cloned repo or your vault.

## Tests

```bash
make test
```
Runs `tests/test_vsync.sh`: creates isolated temporary git repos (cleaned up
automatically when done) to test every command end to end — help, invalid
arguments, `push`/`pull`/sync with no changes, with changes, with new
untracked files, with divergent branches between "two devices", with a real
merge conflict, and `update`/`version` with auto-detected paths. It never
touches your real vault or shell configuration.
