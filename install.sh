#!/usr/bin/env bash
# buchhwin desktop — turn a bare Fedora Server 44 into a niri desktop.
#
#   ./install.sh                     everything
#   ./install.sh --minimal           no applications
#   ./install.sh --wallpapers <dir>  copy wallpapers from <dir> and use them
#   ./install.sh --only <phase>      one phase; repeatable
#   ./install.sh --skip <phase>      all but one; repeatable
#
# There is no `--with citrix`. Citrix cannot be automated — its RPM exists only
# behind a link that is regenerated on every page load — and an option that only
# prints "not automated yet" is a promise the installer does not keep.
# docs/CITRIX.md has the manual route, including why it needs `--nodeps`.
#
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

MINIMAL=0; WALLPAPERS=""; ONLY=(); SKIP=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --minimal)    MINIMAL=1 ;;
        --wallpapers) WALLPAPERS="${2:?}"; shift ;;
        --only)       ONLY+=("${2:?}"); shift ;;
        --skip)       SKIP+=("${2:?}"); shift ;;
        -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done
export MINIMAL WALLPAPERS

should_run() {
    local p="$1" s
    for s in "${SKIP[@]:-}"; do [[ "$s" == "$p" ]] && return 1; done
    (( ${#ONLY[@]} )) || return 0
    for s in "${ONLY[@]}"; do [[ "$s" == "$p" ]] && return 0; done
    return 1
}

for phase_file in "$REPO_DIR"/lib/[0-9][0-9]-*.sh; do
    # shellcheck source=/dev/null
    source "$phase_file"
done

run_phase() { should_run "$1" && "phase_$1"; return 0; }

run_phase preflight
# ⚠️ SECOND, and the position is the point. The akmod build is the slowest and
# most failure-prone step in the installer; discovering after forty minutes that
# the running kernel has no headers is worse than discovering it after one. It
# needs nothing from `base` because the detector reads sysfs rather than lspci.
run_phase gpu
run_phase base
run_phase desktop
run_phase apps
# ⚠️ AFTER `apps`, and it has to be: `dnf swap mesa-va-drivers ...` requires
# mesa to already be installed, and mesa arrives with niri in `desktop`.
# Both phases live in lib/10-gpu.sh — they share rpmfusion_enable().
run_phase codecs
run_phase fonts
run_phase cursors
run_phase shell
run_phase services
# ⚠️ AFTER `services`, because it changes the login shell and that is the last
# thing to touch: if anything earlier fails, the account still logs in.
run_phase shellenv
run_phase summary

# An `--only` run that filters out `summary` must still exit 0. The previous
# project ended on `should_run summary && phase_summary`, so every such run
# reported failure while having done exactly what was asked.
exit 0
