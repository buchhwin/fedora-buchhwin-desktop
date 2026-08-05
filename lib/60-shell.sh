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

    # ---------------------------------------------------------------- images
    #
    # Wallpapers are NOT in the repository. They are somebody's photographs,
    # tens of megabytes each, and this repository is public — so the installer
    # copies them from wherever they actually live and the default falls back
    # to what Fedora already ships. A stranger who clones this gets a working
    # picker; the machine it was built for gets its own pictures.
    local wp_dir="$HOME/Bilder/Wallpaper"
    local wp_src="${WALLPAPERS:-}"
    if [[ -z "$wp_src" ]]; then
        if [[ -d "$REPO_DIR/wallpapers" ]]; then
            wp_src="$REPO_DIR/wallpapers"
        elif [[ -d /usr/share/backgrounds ]]; then
            wp_src="/usr/share/backgrounds"
        fi
    fi

    if [[ -n "$wp_src" && -d "$wp_src" ]]; then
        mkdir -p "$wp_dir"
        # ⚠️ Top level only, and no __MACOSX: a folder that came off a Mac
        # carries a shadow tree of resource forks that are not images, and
        # FolderListModel would happily list them as broken tiles.
        find "$wp_src" -maxdepth 1 -type f \
             \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
                -o -iname '*.gif' -o -iname '*.avif' -o -iname '*.jxl' \) \
             ! -name '.*' -exec cp -n {} "$wp_dir/" \; 2>/dev/null
        ok "wallpapers in $wp_dir ($(find "$wp_dir" -maxdepth 1 -type f | wc -l))"
    fi

    # The first image in the folder, as the file:// URL the shell stores.
    local wp_first
    wp_first="$(find "$wp_dir" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | sort | head -1)"

    # Seeded once. Never overwritten: this file is the user's, and the shell
    # has a default for every key, so an old file cannot be "too old".
    mkdir -p "$CONFIG_HOME/buchhwin"
    if [[ -f "$CONFIG_HOME/buchhwin/shell.json" ]]; then
        ok "settings kept (shell.json exists)"
    elif [[ -n "$wp_first" ]]; then
        # The default scheme is derived from the wallpaper, not shipped. Which
        # image it is does not matter — any of them produces a palette, and the
        # picker changes it in one keystroke.
        printf '{\n  "version": 2,\n  "theme": { "palette": "wallpaper", "accent": "blue" },\n  "wallpaper": { "folder": "%s", "current": "file://%s" }\n}\n' \
            "$wp_dir" "$wp_first" > "$CONFIG_HOME/buchhwin/shell.json"
        ok "settings seeded — scheme derived from $(basename "$wp_first")"
    else
        # No pictures anywhere. Everforest is the raft, not the destination:
        # a desktop with no colours at all is worse than a green one.
        printf '{\n  "version": 2,\n  "theme": { "palette": "everforest-dark", "accent": "green" }\n}\n' \
            > "$CONFIG_HOME/buchhwin/shell.json"
        warn "no wallpapers found — seeded with Everforest Dark instead"
    fi

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
    # ⚠️ This also BUILDS the derived palette when the seed above chose it:
    # loading the "wallpaper" palette is what makes the shell read the image
    # and write theme/palettes/wallpaper.json. Which is why the listing below
    # comes afterwards — before it, that file does not exist yet.
    run_tool render && ok "theme rendered"

    # The palette picker reads this instead of globbing at runtime.
    ( cd "$REPO_DIR/shell/theme/palettes" && ls -1 ./*.json 2>/dev/null \
        | sed 's|^\./||; s|\.json$||' ) > "$REPO_DIR/shell/theme/palettes/index.txt"

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
