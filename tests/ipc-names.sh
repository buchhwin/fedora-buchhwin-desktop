#!/usr/bin/env bash
#
# No IPC function may be called `show`.
#
# ⚠️ MEASURED, NOT STYLE. `qs ipc show` is quickshell's own subcommand, so an
# IPC function of that name cannot be reached from the command line at all:
#
#   $ qs -c buchhwin ipc call launcher show
#   target launcher
#     function toggle(): void
#     …                              <- the listing, and the launcher stayed closed
#   $ qs -c buchhwin ipc call launcher toggle
#   $ qs -c buchhwin ipc call launcher state
#   open                             <- the same handler, a different name, works
#
# Nothing user-facing depended on it — both key bindings use `toggle` — which is
# precisely why it sat there broken. A function nobody can call is the same debt
# as a config key nobody reads.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

printf '  %-34s ' "no IPC function named 'show'"

# Only inside IpcHandler blocks: Ipc.show() as an internal QML function is fine
# and is used by half the shell.
bad="$(awk '
    /IpcHandler[ \t]*\{/          { depth = 1 ; next }
    depth == 0                    { next }
    /\{/                          { depth++ }
    /\}/                          { depth-- ; if (depth <= 0) depth = 0 }
    /^[ \t]*function[ \t]+show[ \t]*\(/ { printf "%s:%d %s\n", FILENAME, NR, $0 }
' shell/ipc/*.qml)"

if [[ -z "$bad" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
    exit 0
fi
printf '\033[38;5;203mfound\033[0m\n'
sed 's/^/      /' <<< "$bad"
echo
echo "  Rename it — 'open' is what the launcher uses. The command line cannot"
echo "  reach a function called 'show', and it fails by printing a listing"
echo "  rather than by saying so."
exit 1
