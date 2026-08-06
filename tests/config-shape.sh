#!/usr/bin/env bash
#
# No `property var` inside a nested JsonObject.
#
# ⚠️ THIS IS A CRASH TRIPWIRE, NOT A STYLE RULE. quickshell segfaulted on
# roughly half of every start for at least a week, always with the same
# backtrace:
#
#   QV4::QObjectWrapper::wrap
#   QQmlVMEMetaObject::writeProperty
#   QMetaProperty::write
#   qs::io::JsonAdapter::deserializeRec      <- TWICE: a nested object
#   qs::io::JsonAdapter::deserializeAdapter
#   qs::io::FileViewAdapter::onDataChanged
#
# Bisected on the machine, one config key at a time, twelve runs each:
#
#   {}                                    0/10 crashes
#   {"keys":{}}                           0/10
#   {"keys":{"binds":[]}}                 6/12   <- var, NESTED
#   {"keys":{"binds":[ …63 objects… ]}}   4/12   <- var, NESTED
#   {"outputs":[ …the same 63 objects… ]} 0/12   <- var, TOP LEVEL
#   {"autostart":["nm-applet"]}           0/10   <- list<string>
#   {"windows":{"blurred":["kitty"]}}     0/12   <- list<string>, nested
#
# An EMPTY nested list is enough, so it is neither the length nor the contents.
# It is writing a `var` property that lives inside a nested JsonObject. Moving
# `binds` to the top level took the same configs from 6/12 to 0/12.
#
# `list<string>` and `list<int>` are safe at any depth — they have a real
# element type and never go through QObjectWrapper::wrap.
#
# So: a `var` in the adapter belongs at the TOP LEVEL. This checks that, because
# the alternative is rediscovering it with another week of "sometimes it does not
# come up".
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

file=shell/config/Config.qml
printf '  %-34s ' "no nested 'property var'"

# Depth is counted in `JsonObject {` openings after the adapter starts. The
# adapter's own body is depth 1, so anything deeper is nested.
bad="$(awk '
    /JsonAdapter[ \t]*\{/            { inadapter = 1 }
    !inadapter                       { next }
    /property JsonObject [A-Za-z_]+: JsonObject \{/ { depth++ ; next }
    /^[ \t]*\}/                      { if (depth > 0) depth-- }
    /^[ \t]*property var [A-Za-z_]+/ {
        if (depth > 0) printf "%s:%d %s\n", FILENAME, NR, $0
    }
' "$file")"

if [[ -z "$bad" ]]; then
    printf '\033[38;5;114mok\033[0m\n'
    exit 0
fi

printf '\033[38;5;203mfound\033[0m\n'
sed 's/^/      /' <<< "$bad"
cat <<'WHY'

  A `property var` inside a nested JsonObject makes quickshell segfault when the
  file supplies that key — about half the time, and it recovers on its own, so
  it looks like "sometimes the shell does not come up" rather than like a bug.

  Two ways out, both fine:
    * move it to the top level of the adapter, next to `binds` and `outputs`
    * give it a real element type: list<string>, list<int>, …

  Moving a key needs a migration; see shell/config/Migrations.qml step 5 -> 6,
  which is the one this check was written for.
WHY
exit 1
