#!/usr/bin/env bash
#
# Every setting has EXACTLY ONE row in the settings window.
#
# ⚠️ THIS IS THE OTHER HALF OF tests/key-readers.sh, and the two together are the
# whole of "alles einstellbar". That one asks whether anything READS a key — it   english-ok: the brief, quoted
# found five that nothing did. This one asks whether anything OFFERS it. A key
# with a reader and no row is a setting you can only reach by editing JSON; a row
# with no key is a control that writes into nothing.
#
# ⚠️ IT CANNOT BORROW key-readers.sh's EXTRACTION, and that is worth spelling out
# because the two files look like they should share one. key-readers.sh matches
# LEAF NAMES: `enabled` exists four times, `monitors` five, and `height`,
# `width`, `size`, `name`, `on` and `mode` more than once each — so `grep -qw
# enabled` is true no matter which one you meant. For "one row per setting" that
# is useless: the question is precisely which of the four. This walks the adapter
# and builds full dotted paths, `input.touchpad.tap` included.
#
# Three directions, and all three are real failures that have happened in this
# project in some form:
#
#   missing    a key with no row      → the promise is broken, quietly
#   twice      a key with two rows    → two controls that can disagree
#   invented   a row with no key      → a control that writes into nothing
#
# The fourth failure — a row labelled for one key that WRITES another — has no
# check here on purpose. It cannot happen: SettingRow reads and writes through
# its `key` and nothing else, so there is no second place for the two to drift
# apart. See shell/ui/settings/SettingRow.qml.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v python3 >/dev/null || { echo "python3 not installed"; exit 2; }

# ─────────────────────────────────────────────────────────────────────────────
# ⚠️ SETTINGS THAT DO NOT HAVE A ROW YET. IT IS EMPTY, AND THAT IS THE POINT.
#
# It is checked in BOTH directions, so a key that gains a row and is not struck
# out fails just as loudly as one that never gets a row at all. That is what
# stops a list like this rotting into a set of excuses — and it has already
# done its job twice: it went red when the six new pages landed and the list
# still claimed a hundred and eight things were owed.
#
# Empty therefore means something exact: **every setting in shell.json can be
# reached from the settings window.** Not "most of them", not "the ones anyone
# thought of" — all 123, counted by this script from the adapter itself.
#
# ⚠️ IT WILL NOT STAY EMPTY, AND THAT IS ALSO THE POINT. Media, Clock & Date and
# Lock Screen have no section in shell.json at all, and neither does the tempo
# of an animation. Those pages need NEW keys — and the moment one is declared
# without a row, this list is where it shows up. Add the key and the row in the
# same change, or write it here with a reason.
PENDING=""

# Settings that will never be a row, each named rather than matched by a
# pattern — a pattern is how an exception list stops being read.
#
#   version   the migration stamp, not a setting
#   binds     63 key bindings; a list with its own view, not a row. ⚠️ And an
#             empty list means "the built-in set", so "no bindings at all" needs
#             an explicit marker rather than an empty box (see Config.qml).
#   outputs   one object per monitor, with a scale and a mode inside it
EXEMPT="version
binds
outputs"

paths="$(python3 - shell/config/Config.qml <<'PY'
import re, sys

# Walk the JsonAdapter and emit one full dotted path per leaf. Brace counting
# rather than indentation: `input` nests a second level, and the day a third
# appears this still answers correctly.
src = open(sys.argv[1]).read().splitlines()
paths, stack, depth, inside = [], [], 0, False
pending_section = pending_depth = None

sec_re  = re.compile(r'property\s+JsonObject\s+([A-Za-z_][A-Za-z0-9_]*)\s*:')
leaf_re = re.compile(r'property\s+(?:list<[a-z]+>|[a-z]+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*:')

for raw in src:
    line = re.sub(r'//.*$', '', raw)      # a comment may hold braces or prose
    if not inside:
        if 'JsonAdapter' in line and '{' in line:
            inside, depth = True, 0
        continue
    m = sec_re.search(line)
    if m:
        pending_section, pending_depth = m.group(1), depth
    else:
        m2 = leaf_re.search(line)
        if m2:
            paths.append('.'.join(stack + [m2.group(1)]))
    for _ in range(line.count('{')):
        depth += 1
        if pending_section is not None and depth == pending_depth + 1:
            stack.append(pending_section)
            pending_section = None
    for _ in range(line.count('}')):
        if stack and len(stack) == depth:
            stack.pop()
        depth -= 1
print('\n'.join(paths))
PY
)"

[[ -n "$paths" ]] || { echo "  could not read any settings out of Config.qml"; exit 1; }

# ⚠️ `^[[:space:]]*key:` and not just `key:`, so that SettingRow's own
# declaration — `property string key: ""` — is not counted as a row.
rows="$(grep -rhoE '^[[:space:]]*key:[[:space:]]*"[^"]+"' shell/ui/settings/ \
        | sed -E 's/.*"([^"]+)".*/\1/')"

want="$(comm -23 <(sort -u <<< "$paths") <(sort <<< "$EXEMPT"))"

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "no row without a setting"

invented="$(comm -13 <(sort -u <<< "$paths") <(sort -u <<< "$rows"))"
# A row is a SettingRow, and a SettingRow without a key is the same fault seen
# from the other side — it would not appear above, because it names nothing.
missing_key=""
while read -r f; do
    [[ -z "$f" ]] && continue
    declared="$(grep -cE '^[[:space:]]*SettingRow[[:space:]]*\{' "$f")"
    keyed="$(grep -cE '^[[:space:]]*key:[[:space:]]*"' "$f")"
    [[ "$declared" == "$keyed" ]] \
        || missing_key+="$f: $declared rows, $keyed keys"$'\n'
done < <(find shell/ui/settings -name '*.qml')

if [[ -n "$invented$missing_key" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    [[ -n "$invented" ]] && sed 's/^/      no such setting: /' <<< "$invented"
    [[ -n "$missing_key" ]] && sed 's/^/      /' <<< "${missing_key%$'\n'}"
    cat <<'WHY'

  A control that writes into nothing. JsonAdapter drops keys it does not
  declare, so the write lands in an object that is thrown away at the next
  parse — the row appears to work and the file never changes.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "no setting has two rows"

twice="$(sort <<< "$rows" | uniq -d)"
if [[ -n "$twice" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    while read -r k; do
        [[ -z "$k" ]] && continue
        printf '      %s\n' "$k"
        # Only `key:` lines. Grepping the bare name also finds it in a comment,
        # which sends the reader to a sentence about the problem instead of to
        # one of the two rows causing it.
        grep -rnE "^[[:space:]]*key:[[:space:]]*\"$k\"" shell/ui/settings/ \
            | sed 's/^/        /'
    done <<< "$twice"
    cat <<'WHY'

  Two controls for one value. They cannot be kept in step by hand: whichever
  page was opened last is the one that looks right, and the other one lies
  until it is touched.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "every kind is one of the six"

badkind="$(grep -rhoE '^[[:space:]]*kind:[[:space:]]*"[^"]+"' shell/ui/settings/ \
           | sed -E 's/.*"([^"]+)".*/\1/' | sort -u \
           | grep -vxE 'switch|slider|choice|field|strings|pick')"
if [[ -n "$badkind" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    sed 's/^/      /' <<< "$badkind"
    cat <<'WHY'

  SettingRow picks its control by this string and falls through to `null` for
  anything it does not know — so a typo draws a label with nothing under it.
WHY
    exit 1
fi
printf '\033[38;5;114mok\033[0m\n'

# ─────────────────────────────────────────────────────────────────────────────
printf '  %-34s ' "the owed list is exactly right"

missing="$(comm -23 <(sort -u <<< "$want") <(sort -u <<< "$rows"))"
forgotten="$(comm -23 <(sort -u <<< "$missing") <(sort -u <<< "$PENDING"))"
stale="$(comm -13 <(sort -u <<< "$missing") <(sort -u <<< "$PENDING"))"

if [[ -n "$forgotten$stale" ]]; then
    printf '\033[38;5;203mfound\033[0m\n'
    [[ -n "$forgotten" ]] && sed 's/^/      no row and not owed: /' <<< "$forgotten"
    [[ -n "$stale" ]] && sed 's/^/      owed but already built: /' <<< "$stale"
    cat <<'WHY'

  "no row and not owed" is a setting that can only be reached by editing JSON,
  with nothing recording that fact. Give it a row, or put it in PENDING with a
  reason.

  "owed but already built" means a row landed and PENDING was not struck out.
  Delete the line — the list is how anyone knows what M8 still owes, and a list
  that overstates is one nobody subtracts from.
WHY
    exit 1
fi

owed="$(grep -c . <<< "$PENDING")"
have="$(grep -c . <<< "$want")"
if [[ "$owed" -eq 0 ]]; then
    printf '\033[38;5;114mok\033[0m  all %s settings have a row\n' "$have"
else
    printf '\033[38;5;114mok\033[0m  %s of %s settings, %s still owed\n' \
           "$(( have - owed ))" "$have" "$owed"
fi
