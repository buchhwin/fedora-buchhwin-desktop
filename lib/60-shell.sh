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
        printf '{\n  "theme": { "palette": "everforest-dark", "accent": "green" }\n}\n' \
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

    section "Theme"
    step "rendering GTK, Qt, kitty and niri colours from the palette"
    render
    ok "theme rendered"
}
