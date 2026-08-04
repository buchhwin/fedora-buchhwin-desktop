# Phase: shell — put the Quickshell configuration where quickshell looks for
# it, seed the user's settings once, and render every foreign application's
# theme from the palette.
phase_shell() {
    section "Shell"

    # `qs -c buchhwin` resolves to this path. A symlink rather than a copy so
    # a git pull is immediately live and there is only ever one tree.
    mkdir -p "$CONFIG_HOME/quickshell"
    ln -sfn "$REPO_DIR/shell" "$CONFIG_HOME/quickshell/buchhwin"
    ok "shell linked to $CONFIG_HOME/quickshell/buchhwin"

    # Seeded once. Never overwritten: this file is the user's, and the shell
    # has a default for every key, so an old file cannot be "too old".
    mkdir -p "$CONFIG_HOME/buchhwin"
    if [[ -f "$CONFIG_HOME/buchhwin/shell.json" ]]; then
        ok "settings kept (shell.json exists)"
    else
        printf '{\n  "version": 1,\n  "theme": { "palette": "everforest-dark", "accent": "green" }\n}\n' \
            > "$CONFIG_HOME/buchhwin/shell.json"
        ok "settings seeded with Everforest Dark"
    fi

    # The palette picker reads this instead of globbing at runtime.
    ( cd "$REPO_DIR/shell/theme/palettes" && ls -1 ./*.json 2>/dev/null \
        | sed 's|^\./||; s|\.json$||' ) > "$REPO_DIR/shell/theme/palettes/index.txt"

    # Wayland, not XWayland — and stated as flags rather than hope.
    # Measured on Fedora 44 + niri: `--ozone-platform-hint=auto` is NOT enough.
    # Brave and Discord fell back to X11 with "Missing X server or $DISPLAY",
    # and VS Code does not even recognise the hint option.
    mkdir -p "$CONFIG_HOME"
    printf -- '--ozone-platform=wayland\n--enable-features=UseOzonePlatform,WaylandWindowDecorations\n' \
        > "$CONFIG_HOME/brave-flags.conf"
    printf -- '--ozone-platform=wayland\n--enable-features=UseOzonePlatform,WaylandWindowDecorations\n' \
        > "$CONFIG_HOME/code-flags.conf"
    ok "browser and editor pinned to Wayland"

    # FileView writes a file, it does not create the folder above it. On a
    # fresh machine none of these exist yet.
    mkdir -p "$CONFIG_HOME/niri" "$CONFIG_HOME/environment.d" \
             "$CONFIG_HOME/gtk-3.0" "$CONFIG_HOME/gtk-4.0" \
             "$CONFIG_HOME/kitty" "$CONFIG_HOME/qt6ct/colors"

    section "Theme"
    step "rendering GTK, Qt, kitty and niri colours from the palette"
    run_tool render && ok "theme rendered"

    section "Compositor"
    # ⚠️ Order matters on a fresh machine: if niri starts before this file
    # exists it writes its OWN default config — the one that spawns waybar —
    # and that file then wins, because we never overwrite silently.
    step "generating ~/.config/niri/config.kdl from shell.json"
    if run_tool niri; then
        if command -v niri >/dev/null; then
            if niri validate -c "$CONFIG_HOME/niri/config.kdl" >/dev/null 2>&1; then
                ok "niri config generated and validated"
            else
                warn "generated niri config does NOT validate — run: niri validate -c $CONFIG_HOME/niri/config.kdl"
            fi
        else
            ok "niri config generated (niri not installed yet, not validated)"
        fi
    fi
}
