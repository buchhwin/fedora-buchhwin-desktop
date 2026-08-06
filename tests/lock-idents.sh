#!/usr/bin/env bash
#
# Every name the lock screen uses has to exist in the lock screen.
#
# ⚠️ THIS IS THE OTHER HALF OF tests/lock.sh, AND IT CATCHES THE ONE THAT COST
# FOUR ROUNDS. `Keys.onPressed` wrote into `field`; the field is called `input`.
# Building the file cannot find that: the handler only runs when a key is
# pressed, and then QML throws a ReferenceError into a log nobody reads, drops
# the character, and the password box stays empty. Four handovers in a row said
# "nobody has ever typed the password" while the reason sat in one identifier.
#
# So this reads rather than runs: collect every name the directory DECLARES —
# ids, properties, signals, functions, function parameters, `var`s — and report
# every `something.` that is none of them.
#
# ⚠️ ONLY shell/ui/lock/. The same check over the whole shell would be a
# false-alarm generator: a surface legitimately reaches ids in files it is
# nested into, and a check nobody trusts costs more than it saves. The lock
# screen is two files and one process, which is exactly the shape this works on.
#
# ⚠️ AND COMMENTS ARE STRIPPED FIRST. Without that, the check reports the prose
# that explains it: a sentence ending in "…the words." looks exactly like
# `words.` to a regular expression. This project has now made that mistake three
# times, and this is the file where it would have been funniest.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

dir=shell/ui/lock
fail=0

mapfile -t files < <(find "$dir" -name '*.qml' | sort)
(( ${#files[@]} )) || { echo "  no QML in $dir"; exit 1; }

printf '  %-34s ' "every name in $dir resolves"

report="$(awk '
    # ---- strings, then comments. In that order, or a // inside a string eats
    # the rest of a real line.
    function clean(s) {
        gsub(/"[^"]*"/, "\"\"", s)
        gsub(/\047[^\047]*\047/, "\047\047", s)
        sub(/\/\/.*/, "", s)
        return s
    }
    BEGIN {
        # QML grouped properties and JS globals: real names that are declared
        # nowhere in the file because they belong to Qt or to the language.
        split("anchors font layer border margins padding sourceSize anchors " \
              "console parent modelData point event Math JSON Date parseInt " \
              "parseFloat String Number Array Object Boolean RegExp isNaN " \
              "undefined arguments this window", g, " ")
        for (i in g) known[g[i]] = 1
    }
    {
        line = clean($0)

        # ---- what this directory declares ------------------------------
        if (match(line, /(^|[^A-Za-z0-9_])id:[ \t]*[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*id:[ \t]*/, "", s)
            known[s] = 1
        }
        if (match(line, /property[ \t]+[A-Za-z_<>0-9]+[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*[ \t]/, "", s)
            known[s] = 1
        }
        if (match(line, /property[ \t]+alias[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*[ \t]/, "", s)
            known[s] = 1
        }
        if (match(line, /signal[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*[ \t]/, "", s)
            known[s] = 1
        }
        if (match(line, /function[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*[ \t]/, "", s)
            known[s] = 1
        }
        # function parameters, both shapes: `function (a, b)` and `function f(a)`
        if (match(line, /function[ \t]*[A-Za-z_0-9]*[ \t]*\([^)]*\)/)) {
            s = substr(line, RSTART, RLENGTH)
            sub(/^[^(]*\(/, "", s); sub(/\).*$/, "", s)
            n = split(s, p, /[ \t,]+/)
            for (i = 1; i <= n; i++) if (p[i] ~ /^[A-Za-z_]/) known[p[i]] = 1
        }
        # locals
        if (match(line, /(^|[^A-Za-z0-9_])var[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
            s = substr(line, RSTART, RLENGTH); sub(/.*[ \t]/, "", s)
            known[s] = 1
        }

        # ---- and what it uses ------------------------------------------
        rest = line
        while (match(rest, /[A-Za-z_][A-Za-z0-9_]*\./)) {
            u = substr(rest, RSTART, RLENGTH - 1)
            pre = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : " "
            # ⚠️ THE DOT STAYS. Cutting past it turns `pam.message.length` into
            # a fresh look at `message.` with nothing in front of it, and the
            # check reports a member of PAM as an undeclared name. Keeping the
            # separator is what makes the "not the first name in a chain" test
            # work at all — it reported two of these before it was kept.
            rest = substr(rest, RSTART + RLENGTH - 1)
            # A member of something else (`a.b.c`) is not a name in its own
            # right, and an upper-case first letter is a type or a singleton.
            if (pre == "." || u ~ /^[A-Z]/) continue
            uses[u] = uses[u] FILENAME ":" FNR " "
        }
    }
    END {
        for (u in uses)
            if (!(u in known)) {
                n = split(uses[u], where, " ")
                print u "\t" where[1]
            }
    }
' "${files[@]}")"

if [[ -z "$report" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
else
    printf '\033[38;5;203m%s unknown\033[0m\n' "$(wc -l <<< "$report")"
    while IFS=$'\t' read -r name where; do
        printf '      \033[38;5;203m%-18s\033[0m %s — declared nowhere in %s\n' \
               "$name" "$where" "$dir"
    done <<< "$report"
    cat <<'EOF'

  A name used here exists in no file under shell/ui/lock/. In QML that is not
  an error you see: the binding or handler throws a ReferenceError, the value
  stays at its default, and everything looks almost right. `field` instead of
  `input` swallowed every keystroke on the lock screen for four rounds.

  If the name really does come from somewhere else, it belongs behind a type
  or a singleton — those start with a capital letter and are not checked here.
EOF
    fail=1
fi

exit $fail
