#!/usr/bin/env bash
#
# The generated niri config must parse — and it must parse cleanly.
#
# `niri validate` exits 1 only on a HARD error. Deprecated keys, an opacity
# outside 0..1, a duplicated output block: all of those exit 0 with either a
# warning or complete silence. So this checks the exit code AND the stderr, or
# it would happily pass a config that niri complains about on every start.
#
# It also validates a real file on disk rather than a process substitution:
# relative include paths resolve against the including file, and /dev/fd is not
# a directory that contains colors.kdl.
#
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }
command -v niri >/dev/null || { echo "niri not installed"; exit 2; }

fail=0
check() {   # $1 = label, $2 = shell.json contents ("" = no file at all)
    local label="$1" json="$2"
    printf '  %-34s ' "$label"

    local tmp; tmp="$(mktemp -d)"
    mkdir -p "$tmp/buchhwin" "$tmp/niri" "$tmp/environment.d"
    [[ -n "$json" ]] && printf '%s\n' "$json" > "$tmp/buchhwin/shell.json"

    rm -f /tmp/buchhwin-niri.log
    XDG_CONFIG_HOME="$tmp" BUCHHWIN_TOOL=niri QT_QPA_PLATFORM=offscreen \
        timeout 60 qs -p shell >/dev/null 2>&1

    if [[ ! -f "$tmp/niri/config.kdl" ]]; then
        printf '\033[38;5;203mno config generated\033[0m\n'; fail=1; rm -rf "$tmp"; return
    fi
    # The generator exits 0 even when it gives up; its report is the truth.
    if grep -q ABORT /tmp/buchhwin-niri.log 2>/dev/null; then
        printf '\033[38;5;203mgenerator aborted\033[0m\n'; fail=1; rm -rf "$tmp"; return
    fi

    local out rc
    out="$(NO_COLOR=1 niri validate -c "$tmp/niri/config.kdl" 2>&1)"; rc=$?
    if (( rc != 0 )); then
        printf '\033[38;5;203minvalid\033[0m\n'
        sed 's/^/      /' <<< "$out" | head -12
        fail=1; rm -rf "$tmp"; return
    fi
    # Exit 0 is not enough — see the header.
    if grep -qi 'warn' <<< "$out"; then
        printf '\033[38;5;203mvalid but warns\033[0m\n'
        grep -i warn <<< "$out" | sed 's/^/      /' | head -6
        fail=1; rm -rf "$tmp"; return
    fi

    printf '\033[38;5;114mok\033[0m  %s lines\n' "$(wc -l < "$tmp/niri/config.kdl")"
    rm -rf "$tmp"
}

# A fresh machine has no settings file at all; the defaults must still produce
# a working compositor, because that is the state right after installation.
check "defaults (no shell.json)" ""
check "everforest-dark" '{"version":1,"theme":{"palette":"everforest-dark","accent":"green"}}'
check "borders on, wide gaps" '{"version":1,"look":{"borderWidth":3,"gapsOut":24}}'
check "minimal profile (blur off)" '{"version":1,"look":{"profile":"minimal"}}'
check "bar on, dock on" '{"version":1,"bar":{"enabled":true},"surfaces":{"dock":true}}'
check "german keyboard, no touchpad tap" \
      '{"version":1,"input":{"keyboard":{"layout":"de","variant":"nodeadkeys"},"touchpad":{"tap":false,"naturalScroll":false}}}'
check "an output override" \
      '{"version":1,"outputs":[{"name":"eDP-1","mode":"1920x1080@60.000","scale":1.5,"x":0,"y":0,"vrr":true}]}'
check "extra autostart + floating rule" \
      '{"version":1,"autostart":["nm-applet"],"windows":{"floating":["pavucontrol"],"blockFromScreencast":["keepassxc"]}}'
# A program that is not configured must DROP its key rather than emit a binding
# to nothing — and the result still has to parse.
check "no terminal configured" '{"version":1,"programs":{"terminal":[]}}'

# Regenerating must be a no-op: niri live-reloads on every write, so a rewrite
# that changes nothing still costs a full compositor reload.
printf '  %-34s ' "second run writes nothing"
tmp="$(mktemp -d)"; mkdir -p "$tmp/buchhwin" "$tmp/niri" "$tmp/environment.d"
printf '{"version":1}\n' > "$tmp/buchhwin/shell.json"
for _ in 1 2; do
    XDG_CONFIG_HOME="$tmp" BUCHHWIN_TOOL=niri QT_QPA_PLATFORM=offscreen \
        timeout 60 qs -p shell >/dev/null 2>&1
done
if grep -q '0 written' /tmp/buchhwin-niri.log; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mrewrote unchanged files\033[0m\n'; fail=1
fi
rm -rf "$tmp"

exit $fail
