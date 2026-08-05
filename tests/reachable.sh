#!/usr/bin/env bash
#
# Nothing is generated into a void.
#
# The renderer writes seven files, and "change the palette, everything follows"
# is only true if something actually READS each one. GTK finds gtk.css and
# settings.ini by itself; kitty and qt6ct do not. kitty reads kitty.conf and
# only the files it `include`s, qt6ct reads qt6ct.conf and only the colour
# scheme named there — and for a long time neither pointer existed. The terminal
# theme was written to ~/.config/kitty/theme.conf on every palette change and
# read by nobody, so the terminal sat at kitty's own black throughout, while the
# renderer reported success each time. Writing had worked. Nothing else had.
#
# This runs the REAL installer phase into a throwaway config home, so it checks
# what ships rather than a copy of it that can drift.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

fail=0
pass() { printf '  \033[38;5;114mok\033[0m    %s\n' "$1"; }
bad()  { printf '  \033[38;5;203mFAIL\033[0m  %s\n' "$1"; fail=1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cfg="$work/config"
mkdir -p "$cfg"

# ⚠️ KEEP BOTH REPORTS, because "not written" on its own is a dead end.
#
# That is exactly what this suite said the last time it went red, and it is
# what a refusal, a crash and a genuinely skipped file all look like from out
# here. The renderer's own log tells the three apart — it ends at "start" when
# the process died, at "ABORT" when it refused, at "done" when it ran — and the
# installer's output carries the warning run_tool prints. Both were being sent
# to /dev/null, so the one run that mattered was undiagnosable.
#
# The log is a fixed path shared by every run, so it is copied HERE: this
# script installs twice, and the second run would otherwise overwrite the
# evidence from the first.
rm -f /tmp/buchhwin-render.log
XDG_CONFIG_HOME="$cfg" timeout 120 bash install.sh --only shell >"$work/install.log" 2>&1
cp -f /tmp/buchhwin-render.log "$work/render.log" 2>/dev/null || true

why() {
    printf '        ---- renderer log ----\n'
    sed 's/^/        /' "$work/render.log" 2>/dev/null || printf '        (no log at all)\n'
    if grep -qE 'warn|fail|abort' "$work/install.log" 2>/dev/null; then
        printf '        ---- installer complaints ----\n'
        grep -iE 'warn|fail|abort' "$work/install.log" | sed 's/^/        /'
    fi
}

# Written at all.
missing=0
for pair in \
    "gtk3 css|$cfg/gtk-3.0/gtk.css" \
    "gtk3 settings|$cfg/gtk-3.0/settings.ini" \
    "gtk4 css|$cfg/gtk-4.0/gtk.css" \
    "kitty theme|$cfg/kitty/theme.conf" \
    "qt6ct colours|$cfg/qt6ct/colors/buchhwin.conf"
do
    label="${pair%%|*}"; path="${pair##*|}"
    if [[ -s "$path" ]]; then pass "written: $label"
    else bad "not written: $label ($path)"; missing=1; fi
done
(( missing )) && why

# Reachable — the half that used to be missing.
if grep -qE '^ *include  *theme\.conf' "$cfg/kitty/kitty.conf" 2>/dev/null; then
    pass "kitty.conf includes the generated theme"
else
    bad "kitty.conf does not include theme.conf — the palette never reaches the terminal"
fi

if grep -q 'colors/buchhwin\.conf' "$cfg/qt6ct/qt6ct.conf" 2>/dev/null; then
    pass "qt6ct.conf selects the generated colours"
else
    bad "qt6ct.conf does not select colors/buchhwin.conf — Qt apps keep their own"
fi

# And the terminal's transparency lands in the file kitty reads, rather than
# being left to the compositor, which fades the text along with it.
if grep -q '^background_opacity ' "$cfg/kitty/theme.conf" 2>/dev/null; then
    pass "the terminal's background opacity is written"
else
    bad "no background_opacity in the kitty theme"
fi

# A second run must not fight the user's own file.
printf '# mine\ninclude theme.conf\nfont_size 14\n' > "$cfg/kitty/kitty.conf"
XDG_CONFIG_HOME="$cfg" timeout 120 bash install.sh --only shell >/dev/null 2>&1
if grep -q '^font_size 14' "$cfg/kitty/kitty.conf"; then
    pass "an existing kitty.conf is left alone"
else
    bad "the installer overwrote a kitty.conf that already existed"
fi

exit $fail
