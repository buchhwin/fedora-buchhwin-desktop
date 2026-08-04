#!/usr/bin/env bash
# Shared installer helpers.
#
# The installer is the ONLY bash in this project, and it deliberately contains
# no configuration logic: it installs packages, places files and enables
# services. Everything that decides how the desktop looks or behaves is QML,
# rendered by `qs` — including on a machine that has no session yet.

set -uo pipefail

C_OK=$'\033[38;5;114m'; C_WARN=$'\033[38;5;179m'; C_ERR=$'\033[38;5;203m'
C_DIM=$'\033[2m'; C_OFF=$'\033[0m'

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

WARNINGS=0
section() { printf '\n%s==>%s %s\n' "$C_OK" "$C_OFF" "$*"; }
step()    { printf '  %s\n' "$*"; }
ok()      { printf '  %s✓%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn()    { printf '  %s!%s %s\n' "$C_WARN" "$C_OFF" "$*"; WARNINGS=$((WARNINGS+1)); }
die()     { printf '  %sx%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

# Package lists are plain text with comments; this is the only parser.
read_list() {
    local f="$REPO_DIR/packages/$1"
    [[ -f "$f" ]] || die "missing package list: $f"
    grep -vE '^[[:space:]]*(#|$)' "$f" | sed 's/[[:space:]]*#.*//' | tr -d ' '
}

dnf_install() {
    local weak="$1"; shift
    (( $# )) || return 0
    local args=(-y)
    [[ "$weak" == "noweak" ]] && args+=(--setopt=install_weak_deps=False)
    sudo dnf install "${args[@]}" "$@"
}

# `qs` is how this project renders anything. Running it headless is a first
# class path, not a trick: the installer and a running session use the same
# code, so a fresh machine and a palette switch cannot drift apart.
render() {
    command -v qs >/dev/null || { warn "quickshell not installed yet; skipping render"; return 0; }
    BUCHHWIN_TOOL=render QT_QPA_PLATFORM=offscreen \
        timeout 60 qs -p "$REPO_DIR/shell" >/dev/null 2>&1 \
        || warn "render pass failed — run 'bhctl theme apply' after logging in"
}
