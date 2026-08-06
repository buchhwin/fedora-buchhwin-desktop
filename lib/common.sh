#!/usr/bin/env bash
# Shared installer helpers.
#
# The installer is the ONLY bash in this project, and it deliberately contains
# no configuration logic: it installs packages, places files and enables
# services. Everything that decides how the desktop looks or behaves is QML,
# rendered by `qs` — including on a machine that has no session yet.

set -uo pipefail

C_OK=$'\033[38;5;114m'; C_WARN=$'\033[38;5;179m'; C_ERR=$'\033[38;5;203m'; C_OFF=$'\033[0m'

# ⚠️ These four are used by the PHASE files that source this one, so shellcheck
# — which reads one file at a time — cannot see it and reports them as unused.
# Silenced with a reason rather than left to be scrolled past: a warning nobody
# can act on trains everyone to ignore the ones that matter.
#
# `C_DIM` used to be here too and really was unused, in every file. It was
# deleted rather than silenced, which is the other half of the same rule.
# shellcheck disable=SC2034
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC2034
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
# shellcheck disable=SC2034
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
# shellcheck disable=SC2034
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
#
# Quickshell leaves an instance directory behind for EVERY run and never removes
# one. Measured on the test machine after two days: 407 directories, 15 MB, in
# /run/user/<uid> — which is a tmpfs, so it is RAM. Each run adds exactly one.
#
# ⚠️ NOT `flock` ON instance.lock. That is the obvious way to tell a live
# instance from a dead one and it does not work: measured, `flock -n` succeeded
# on all 407 of them INCLUDING the directory belonging to the running shell, so
# a prune built on it would have deleted the live instance's socket out from
# under it.
#
# `qs list` names the instances that are actually alive. Anything else under
# by-id/ belongs to a process that is gone.
prune_instances() {
    local dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/by-id"
    [[ -d "$dir" ]] || return 0
    command -v qs >/dev/null || return 0

    local live
    # ⚠️ If the listing itself fails, do NOTHING. An empty answer would
    # otherwise read as "nothing is alive" and take the running shell with it.
    live="$(qs list --all --json 2>/dev/null)" || return 0
    [[ -n "$live" ]] || return 0
    live="$(printf '%s' "$live" | sed -n 's/.*"id": "\([^"]*\)".*/\1/p')"

    local d name
    for d in "$dir"/*/; do
        [[ -d "$d" ]] || continue
        name="$(basename "$d")"
        printf '%s\n' "$live" | grep -qxF "$name" && continue
        rm -rf "$d"
    done
}

# One helper for every tool, rather than one function per tool hardcoding its
# own name — there were two copies of this, in common.sh and in bin/bhctl, and
# adding the niri generator would have meant editing both.
run_tool() {
    local tool="$1"
    local log="/tmp/buchhwin-$tool.log"
    command -v qs >/dev/null || { warn "quickshell not installed yet; skipping $tool"; return 0; }
    if ! BUCHHWIN_TOOL="$tool" QT_QPA_PLATFORM=offscreen \
            timeout 60 qs -p "$REPO_DIR/shell" >/dev/null 2>&1; then
        warn "$tool pass failed — run 'bhctl $tool apply' after logging in"
        return 1
    fi
    # The tools exit 0 even when they abort, so their own report is the only
    # place a failure shows. Surfacing it here is the difference between a
    # warning and a desktop that quietly has no colours.
    if [[ -f "$log" ]] && grep -q 'ABORT' "$log"; then
        warn "$tool aborted: $(grep -m1 -A1 'ABORT' "$log" | tail -1 | sed 's/^ *//')"
        return 1
    fi
    return 0
}

render() { run_tool render; }
