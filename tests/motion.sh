#!/usr/bin/env bash
#
# The tripwire for motion.
#
# ⚠️ THIS EXISTS BECAUSE TUNING NUMBERS DID NOT WORK TWICE. The animations were
# reported as stuttering, the durations were changed (320 → 200 → 150 ms) and the
# curve was changed (OutExpo → OutCubic), and both times the answer came back:
# still stuttering, on a Ryzen 7 7840HS with a Radeon 780M. A machine like that
# does not struggle to slide a panel. The cost was never in the numbers.
#
# It was this: a `Behavior` on a size that a WAYLAND LAYER SURFACE is sized
# from. Animating that property re-sizes the surface once per frame, and a
# surface re-size is not drawing — it is a `set_size` plus an `ack_configure`
# round trip with niri, a buffer of a new size (so the swapchain is discarded
# every frame), a fresh corner-radius and blur calculation, and a new input
# region. Measured on the VM at 60 Hz, ONE opening of the quick panel:
#
#     before   11 × set_size, 9 × ack_configure     one per frame
#     after     0 × for the notch, 3 × for a page   once per content stage
#
# At 144 Hz the "before" number is about 21 and the "after" number is still 3,
# which is the difference between a cost that scales with the refresh rate and
# one that does not.
#
# So there are two checks here, and the first one is the important one:
#
#   1. HARD — a PanelWindow's implicit size may not be bound to a property that
#      something animates. This is the fault that cost two rounds.
#   2. SOFT — a `Behavior` on any layout size has to say why. Some are correct
#      (a level bar's fill really is a width; a card that folds really does
#      change height). Each one states its reason at the site, so the next
#      person meets the argument rather than the pattern.
#
# An exception is written on the line or the line above it:
#
#     Behavior on width { ... }        // motion-ok: a fill level, not a layout
#
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
report() { printf '  \033[38;5;203m%s\033[0m  %s\n' "$1" "$2"; fail=1; }
note()   { printf '  \033[38;5;245m%s\033[0m  %s\n' "$1" "$2"; }

layout_props='width|height|implicitWidth|implicitHeight|Layout\.[A-Za-z]+'

# ---------------------------------------------------------------------- hard
# A PanelWindow sizes a Wayland layer surface. If its implicit size reads a
# property that is animated somewhere in the same file, every frame of that
# animation is a round trip with the compositor.
while IFS= read -r file; do
    grep -q 'PanelWindow' "$file" || continue

    # Every property this file animates.
    animated=$(grep -oE '^[[:space:]]*Behavior on [A-Za-z_][A-Za-z0-9_]*' "$file" \
               | awk '{print $3}' | sort -u)
    [[ -z "$animated" ]] && continue

    while IFS= read -r hit; do
        line=${hit%%:*}
        text=${hit#*:}
        [[ -z "${line:-}" ]] && continue
        [[ "$text" == *"motion-ok"* ]] && continue

        # ⚠️ ONLY THE RIGHT-HAND SIDE. The first version of this matched the
        # whole line, so `implicitWidth: …` matched the animated property
        # `implicitWidth` by its own DECLARATION and reported every such line
        # whether or not it referenced anything animated. It happened to be red
        # on the real bug, which is exactly how a broken check survives — and it
        # missed ShellSurface.qml completely, where the reference is
        # `root.islandW` and the declaration is `implicitWidth`.
        rhs=${text#*:}

        for prop in $animated; do
            # `islandW`, `root.islandW` and `card.implicitWidth` all count;
            # `islandWidth` does not, which is why the boundary is spelled out.
            if printf '%s' "$rhs" \
               | grep -qE "(^|[^A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*\.)?${prop}([^A-Za-z0-9_]|\$)"; then
                report "surface  $file:$line" \
                       "implicit size follows the animated '$prop'"
            fi
        done
    done < <(grep -nE '^[[:space:]]*implicit(Width|Height)[[:space:]]*:' "$file" 2>/dev/null)
done < <(find shell -name '*.qml' -type f | sort)

# ---------------------------------------------------------------------- soft
# Every Behavior on a layout size states its reason, or it is a finding.
while IFS= read -r file; do
    while IFS=: read -r line text; do
        [[ -z "${line:-}" ]] && continue
        [[ "$text" == *"motion-ok"* ]] && continue

        # ⚠️ THE WHOLE COMMENT BLOCK ABOVE, not just one line. The reasons in
        # this project are paragraphs — the first version of this check only
        # looked one line up, so every reason that took more than a sentence was
        # invisible to it and five correctly-argued exceptions stayed red.
        # Walking up while the lines are comments stops at the first real line,
        # so a reason cannot be borrowed from an unrelated block further away.
        found=0
        n=$((line - 1))
        while (( n > 0 )); do
            prev=$(sed -n "${n}p" "$file")
            trimmed=${prev#"${prev%%[![:space:]]*}"}
            [[ "$trimmed" == //* ]] || break
            if [[ "$prev" == *"motion-ok"* ]]; then found=1; break; fi
            n=$((n - 1))
        done
        (( found )) && continue
        report "layout   $file:$line" \
               "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-60)"
    done < <(grep -nE "^[[:space:]]*Behavior on (${layout_props})[[:space:]]*\{" "$file" 2>/dev/null)
done < <(find shell/ui -name '*.qml' -type f | sort)

if (( fail )); then
    cat <<'EOF'

  A size that decides a layer surface, or a layout, is being animated.

  Animating a PanelWindow's implicit size re-sizes a Wayland surface once per
  frame — protocol traffic, not drawing, and no duration or easing curve can
  make it cheap. Set the size and animate `scale`, `opacity` or `x`/`y`
  instead: those are GPU transforms the compositor never hears about.

  If the motion genuinely is a size — a fill level, a card that folds — say so:

      Behavior on width { ... }   // motion-ok: the fill of a level bar

EOF
    exit 1
fi

note "motion" "no layer surface follows an animated size"
echo "  every animated layout size states its reason"
