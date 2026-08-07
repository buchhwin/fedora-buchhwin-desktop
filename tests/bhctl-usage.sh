#!/usr/bin/env bash
#
# Every subcommand bhctl implements is listed, and every line it lists is real.
#
# ⚠️ THE FAULT THIS EXISTS FOR. `bhctl binds reset` was implemented, and
# `bhctl doctor` printed "run: bhctl binds reset" as its advice — but `usage()`
# did not mention it, and `usage()` is what a bare `bhctl` prints. Its own
# comment calls it "THE ONE HANDLE THAT UNFREEZES A MACHINE", so the one command
# somebody needs when their keys have stopped working could only be found by
# reading the source.
#
# Both directions, because the opposite drift is just as bad: a line advertising
# a subcommand that was renamed sends people to `bhctl: unknown` and reads as a
# broken program rather than a stale document.
#
# Reads the file. Nothing is executed, so this needs no desktop and runs in CI.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0

# The top-level `case "${1:-}" in` labels. Anchored at column 0 because every
# nested case in this file is indented — `reset)` inside `binds)` is not a
# subcommand of its own, and matching it would demand a usage line for it.
#
# ⚠️ QUOTED LABELS COUNT. Two of them are written `"prune")` and `"shell")`,
# and the first version of this pattern silently skipped both — it then reported
# those two usage lines as advertising commands that do not exist, which is the
# opposite of the truth. A check whose extractor is wrong invents faults; the
# quotes are stripped here rather than the pattern being loosened, so a label
# that is genuinely indented still cannot sneak in.
mapfile -t implemented < <(
    sed -n '/^case "${1:-}" in$/,/^esac$/p' bin/bhctl \
    | grep -E '^"?[a-z|]+"?\)$' | tr -d '")' | tr '|' '\n' | sort -u
)
mapfile -t advertised < <(
    sed -n "/^usage() {/,/^}$/p" bin/bhctl \
    | grep -oE '^bhctl [a-z]+' | awk '{print $2}' | sort -u
)

if (( ${#implemented[@]} == 0 )); then
    echo "  found no subcommands — the case block moved?"; exit 2
fi

printf '  %-40s ' "every subcommand is in usage()"
missing=""
for c in "${implemented[@]}"; do
    [[ "$c" == "*" ]] && continue
    printf '%s\n' "${advertised[@]}" | grep -qxF "$c" || missing+=" $c"
done
if [[ -z "$missing" ]]; then
    printf '\033[38;5;114mok\033[0m  %d subcommands\n' "${#implemented[@]}"
else
    printf '\033[38;5;203mnot listed:%s\033[0m\n' "$missing"; fail=1
fi

printf '  %-40s ' "every usage() line is implemented"
ghost=""
for c in "${advertised[@]}"; do
    printf '%s\n' "${implemented[@]}" | grep -qxF "$c" || ghost+=" $c"
done
if [[ -z "$ghost" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mno such subcommand:%s\033[0m\n' "$ghost"; fail=1
fi

# ⚠️ AND THE RESCUE ITSELF, checked by name rather than by counting. `binds
# reset` is the one command in here that somebody reaches for when the desktop
# is already misbehaving, and the check above would go green again the day it
# is deleted from both places at once.
printf '  %-40s ' "the rescue is offered by name"
if grep -q '^bhctl binds reset' bin/bhctl; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mbhctl binds reset is not in usage()\033[0m\n'; fail=1
fi

# ⚠️ AND IT CANNOT SILENTLY DO NOTHING. bin/bhctl runs without `set -e`, so a
# missing python3 let the heredoc fail with 127 while the `exec` after it still
# announced a successful regeneration — over a settings file whose frozen
# bindings were untouched.
printf '  %-40s ' "the rescue cannot fail silently"
block="$(sed -n '/^binds)$/,/^doctor)$/p' bin/bhctl)"
if grep -q 'command -v python3' <<< "$block" && grep -qE 'rc=\$\?' <<< "$block"; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203mno guard before, or no exit code read after, the heredoc\033[0m\n'
    fail=1
fi

exit $fail
