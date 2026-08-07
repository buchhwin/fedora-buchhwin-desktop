#!/usr/bin/env bash
#
# Axis 7: every surface opens AND closes, and leaves nothing behind.
#
# tests/ipc-effect.sh already asks the first half — press the verb, does the page
# appear. This asks the half that only shows up after a while:
#
#   * does it CLOSE again, or does the notch keep a page open that nobody can
#     see because the next one drew over it
#   * is there still exactly ONE quickshell instance afterwards. Quickshell
#     leaves an instance directory behind for every run and never removes one;
#     407 of them, 15 MB of tmpfs, had accumulated on the test machine before
#     `bhctl prune` existed. A surface that spawns a helper and does not reap it
#     is the same leak with a different name.
#   * did anything reach the journal. A binding that throws while a surface is
#     being built does not crash the shell — it leaves the property at its
#     default and writes one line. That is how a white square shipped beside
#     every notification, and how the settings gear did nothing at all for a day.
#
# ⚠️ IT NEEDS A RUNNING SHELL, so it exits 2 without one, exactly as
# tests/ipc-effect.sh and tests/generated-read.sh do. It is deliberately not in
# CI: a build container has no session for it to talk to.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }
# ⚠️ WAYLAND_DISPLAY HAS TO BE RIGHT, and the failure looks like a dead shell:
# `qs ipc call` matches instances by display connection as well as by config
# path, so over an ssh session with no WAYLAND_DISPLAY it answers "No running
# instances" while `qs list --all` cheerfully shows the shell running. Measured,
# after ten minutes of believing the shell had crashed.
qs -c buchhwin ipc call notch state >/dev/null 2>&1 || {
    echo "no running shell to ask (WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset};"
    echo "  over ssh it must name the session's display, e.g. wayland-1)"
    exit 2
}

fail=0

# ⚠️ The same list as tests/ipc-effect.sh, and for the same reason: only verbs
# that OPEN a page. `mic` and its neighbours toggle a service and close
# themselves, so asserting they stay open would be a check that is right nine
# times in ten — which teaches people to ignore it.
verbs="media quick notifications calendar tray workspaces wallpaper theme
event brightness calculator timer session clipboard"

# The journal cursor BEFORE anything is touched, so the comparison covers this
# run and not whatever the shell said at boot.
since="$(date '+%Y-%m-%d %H:%M:%S')"
sleep 1

before="$(ls "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/by-id" 2>/dev/null | wc -l)"

stuck=""
for v in $verbs; do
    qs -c buchhwin ipc call notch "$v" >/dev/null 2>&1
    sleep 0.4
    open="$(qs -c buchhwin ipc call notch state 2>/dev/null | tr -d '[:space:]')"
    qs -c buchhwin ipc call notch collapse >/dev/null 2>&1
    sleep 0.4
    shut="$(qs -c buchhwin ipc call notch state 2>/dev/null | tr -d '[:space:]')"
    # ⚠️ Both halves. Asserting only that it closes would pass a verb that never
    # opened anything at all — the state was already collapsed, so collapsing it
    # again "works". That is exactly the shape `notch settings` had.
    # ⚠️ CLOSED IS THE EMPTY STRING, not the word "collapsed". `notch state`
    # returns `root.page` verbatim (shell/ipc/Ipc.qml:229) and collapsing clears
    # it. Expecting a word here reported all fourteen surfaces as stuck open on
    # a shell that was closing every one of them correctly — the check was right
    # and the expectation was invented.
    [[ "$open" == "$v" ]] || stuck+=" $v(did-not-open:$open)"
    [[ -z "$shut" ]] || stuck+=" $v(did-not-close:$shut)"
done

printf '  %-40s ' "every surface opens and closes again"
if [[ -z "$stuck" ]]; then
    printf '\033[38;5;114mok\033[0m  %d surfaces\n' "$(wc -w <<< "$verbs")"
else
    printf '\033[38;5;203m%s\033[0m\n' "$stuck"; fail=1
fi

printf '  %-40s ' "still exactly one quickshell instance"
after="$(ls "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell/by-id" 2>/dev/null | wc -l)"
if [[ "$after" == "$before" ]]; then
    printf '\033[38;5;114mok\033[0m  %s\n' "$after"
else
    printf '\033[38;5;203m%s before, %s after\033[0m\n' "$before" "$after"; fail=1
fi

printf '  %-40s ' "and nothing reached the journal"
# ⚠️ org.bluez is filtered by name and the reason is written down rather than
# assumed: it is quickshell's own D-Bus probe on a machine with no Bluetooth
# adapter, it appears once at every start, and it belongs to quickshell rather
# than to this shell. Everything else counts — a filter list that grows is a
# filter list that stops finding things.
noise="$(journalctl --user -u buchhwin-shell --since "$since" --no-pager 2>/dev/null \
         | grep -E 'WARN|ERROR|qml:|TypeError|Cannot|undefined|is not a' \
         | grep -v 'org.bluez' || true)"
if [[ -z "$noise" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203m%s line(s)\033[0m\n' "$(wc -l <<< "$noise")"
    head -6 <<< "$noise" | sed 's/^/      /'
    fail=1
fi

exit $fail
