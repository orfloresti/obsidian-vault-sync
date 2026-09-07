#!/usr/bin/env bash
# Checks that vsync's dependencies are actually installed on this device.
set -u

missing=0

check_cmd() {
    local cmd="$1" hint="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  ok      - $cmd ($(command -v "$cmd"))"
    else
        echo "  MISSING - $cmd — $hint" >&2
        missing=1
    fi
}

echo "vsync dependency check:"
check_cmd git "install with: pkg install git (Termux) / apt install git (Debian/Ubuntu) / brew install git (macOS)"
check_cmd bash "install with: pkg install bash (Termux) / apt install bash (Debian/Ubuntu)"
check_cmd sed "used by 'make install'/'make uninstall'; usually preinstalled"
check_cmd grep "used by vsync's commit messages and install scripts; usually preinstalled"

if [ -n "${BASH_VERSION:-}" ]; then
    echo "  ok      - running under bash $BASH_VERSION"
else
    echo "  warn    - \$BASH_VERSION is unset (not running under bash). vsync is written for bash; zsh is supported for sourcing vsync.sh itself, but run this check and 'make install' under bash." >&2
fi

if [ "$missing" -eq 1 ]; then
    echo
    echo "vsync: missing dependencies listed above — install them, then re-run 'make check'." >&2
    exit 1
fi

echo
echo "vsync: all dependencies present."
