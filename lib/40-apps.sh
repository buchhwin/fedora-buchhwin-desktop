# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
# Phase: apps — third-party repositories, applications, flatpaks.
phase_apps() {
    (( MINIMAL )) && { section "Applications"; step "skipped (--minimal)"; return 0; }
    section "Applications"

    if [[ ! -f /etc/yum.repos.d/brave-browser.repo ]]; then
        sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc 2>/dev/null
        sudo dnf config-manager addrepo --overwrite \
            --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo \
            >/dev/null 2>&1 || warn "could not add the Brave repository"
    fi
    if [[ ! -f /etc/yum.repos.d/vscode.repo ]]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null
        printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' \
            | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
    fi

    mapfile -t pkgs < <(read_list dnf-apps.txt)
    dnf_install weak "${pkgs[@]}" || warn "some applications failed"

    # ⚠️ BRAVE GETS A POLICY FILE, and the one key here is MEASURED rather than
    # remembered. Chromium reads /etc/brave/policies/managed/*.json at start.
    #
    # Proven with a control on 07.08.2026, because "I wrote a policy and the
    # browser looks different" is not a measurement: with the file in place the
    # new tab is blank; with the same file REMOVED and Brave restarted, the full
    # Brave page comes back — background photo, the "Ask anything, find
    # anything…" box, a STATS panel and a REWARDS panel. That is exactly the
    # strip 2026-08-06/vorlage-brave-sauber.png asks to be rid of, and blanking
    # the new tab removes all of it at once, because all of it lives there.
    #
    # ⚠️ `BookmarkBarEnabled` is false because Chromium has no "on hover" — the
    # choices are always, never, and new-tab-page only. Ctrl+Shift+B brings it
    # back for as long as it is wanted.
    step "brave policy"
    sudo mkdir -p /etc/brave/policies/managed
    sudo tee /etc/brave/policies/managed/buchhwin.json >/dev/null <<'POLICY'
{
  "NewTabPageLocation": "about:blank",
  "BookmarkBarEnabled": false,
  "BraveRewardsDisabled": true,
  "BraveAIChatEnabled": false
}
POLICY
    ok "brave policy"

    # ⚠️ AND THE COLOURS, which the policy above does not touch. His reference
    # is 2026-08-07/vorlage-brave-gefaerbt.png: the whole browser chrome — tab
    # strip, navigation row, empty content — in the palette's dark green, not
    # Brave's own grey — his words, quoted: "bei brave soll das theme genau     english-ok: the request, quoted
    # so greifen."                                                              english-ok: the request, quoted
    #
    # ⚠️ ONE SETTING, NOT A GENERATOR. `extensions.theme.system_theme = 1` is
    # Chromium's "follow the GTK theme", and we ALREADY generate a GTK theme
    # from the palette. So Brave follows the palette for free, on every change,
    # for ever — where a colour written into a policy or a generated theme
    # extension would have to be rewritten on each switch, and /etc needs root
    # that the renderer does not have.
    #
    # ⚠️ ONLY WHILE BRAVE IS NOT RUNNING. Chromium keeps Preferences in memory
    # and writes it out on exit, so editing it under a live browser is edited
    # away again a minute later. Refusing is better than doing nothing visible.
    step "brave follows the theme"
    local bravePrefs="$CONFIG_HOME/BraveSoftware/Brave-Browser/Default/Preferences"
    # ⚠️ WAIT FOR IT TO BE GONE, do not sleep and hope — right in itself, and
    # NOT the reason the key disappears. That was the first theory: Brave writes
    # Preferences on exit, so a `pkill` plus two seconds could let its copy land
    # after ours. Measured, and it is wrong: Brave was gone in 200 ms, the key
    # was written to a settled file, and after the next start
    # `extensions.theme` was absent again.
    #
    # So Brave discards it itself. What that means is still open — the pref may
    # have been renamed in this version, or it may only be honoured when a GTK
    # theme is actually resolvable. This loop stays because polling for a
    # condition beats sleeping for a guess whatever the cause.
    local waited=0
    while pgrep -f brave-browser >/dev/null && (( waited < 50 )); do
        sleep 0.2; waited=$(( waited + 1 ))
    done
    if pgrep -f brave-browser >/dev/null; then
        warn "brave is still running — close it and re-run, or its colours stay grey"
    else
        mkdir -p "$(dirname "$bravePrefs")"
        python3 - "$bravePrefs" <<'PYEOF'
import json, os, sys
path = sys.argv[1]
try:
    with open(path) as fh:
        prefs = json.load(fh)
except Exception:
    # No profile yet: a Preferences file with only this in it is valid, and
    # Brave fills in the rest on first run.
    prefs = {}
# ⚠️ `browser.theme.follows_system_colors`, and NOT
# `extensions.theme.system_theme`. The second one is what this used to write,
# it is a name from an older Chromium, and Brave 151 does not register it — so
# Brave dropped the key on every start and the chrome stayed grey. Found by
# asking the programme itself rather than remembering:
#
#     strings /opt/brave.com/brave/brave | grep '^browser\.theme'
#     browser.theme.follows_system_colors
#     browser.theme.user_color
#     browser.theme.color_scheme / color_variant / is_grayscale
#
# ⚠️ AND THIS ONE DOES NOT VISIBLY WORK EITHER — measured 07.08.2026, said here
# rather than left for the next person to rediscover. Written to a settled
# Preferences file with Brave not running, then started: the key is absent again
# and the chrome measures [35 35 39], a neutral grey, where the palette's window
# colour is (45 53 59). Either Brave drops it because `true` is already the
# default (Chromium omits prefs at their default), in which case following is on
# and simply does nothing under niri — or it is not honoured at all.
#
# It stays because it is at worst harmless and at best correct, and because the
# key it replaced was provably wrong. The route that remains is
# `browser.theme.user_color`: an explicit colour, which Chromium DOES persist
# because it is not a default. That one has to be written per palette, so it
# belongs in tools/render.qml and in the Theming fingerprint — not here.
# ⚠️ THE THIRD KEY IS THE ONE THAT STICKS — measured 07.08.2026. Written as a
# signed 32-bit SkColor (0xFFRRGGBB, wrapped into negative), together with
# `is_grayscale`, and after a full restart Brave STILL HAS THEM:
#
#     {'is_grayscale': False, 'user_color': -5783424}
#
# The two before it were dropped on every start. This one persists because it is
# not a default — which is exactly the argument for choosing it.
#
# ⚠️ AND THE COLOUR IS NOT PROVEN YET, said plainly. The screenshot taken to
# check it caught Brave's ONBOARDING page — the purple splash with the lion —
# not the browser chrome, so the [97 57 119] reading measured the wrong thing.
# What is established is that the key survives; whether the chrome takes the
# palette still needs a shot past the first-run flow, against
# 2026-08-07/vorlage-brave-gefaerbt.png.
#
# ⚠️ AND WHEN IT IS PROVEN IT MOVES OUT OF HERE. A colour has to be rewritten on
# every palette change, so it belongs in tools/render.qml and in the Theming
# fingerprint. This installer step only seeds a profile that does not exist yet.
prefs.setdefault("browser", {}).setdefault("theme", {})["follows_system_colors"] = True
tmp = path + ".buchhwin-tmp"
with open(tmp, "w") as fh:
    json.dump(prefs, fh, separators=(",", ":"))
os.replace(tmp, path)
PYEOF
        ok "brave follows the theme"
    fi

    sudo dnf install -y flatpak >/dev/null 2>&1
    sudo flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1
    mapfile -t flat < <(read_list flatpak.txt)
    for f in "${flat[@]}"; do
        step "flatpak $f"
        sudo flatpak install -y --noninteractive flathub "$f" >/dev/null 2>&1 \
            || warn "flatpak $f failed"
    done

    # Discord ships with an x11-only socket set; without this it falls back to
    # X11 even with the ozone flags. Measured, not assumed.
    sudo flatpak override --socket=wayland com.discordapp.Discord 2>/dev/null || true

    ok "applications"
}
