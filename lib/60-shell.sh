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
    # ⚠️ NOT "$HOME/Bilder": that is the German name for the pictures folder,
    # and this repository is public. `xdg-user-dir` answers with whatever the
    # machine actually calls it; the fallback is the XDG default rather than a
    # translation, because a machine with no user-dirs file has no German
    # folder either.
    local pics
    pics="$(xdg-user-dir PICTURES 2>/dev/null)"
    [[ -n "$pics" && "$pics" != "$HOME" ]] || pics="$HOME/Pictures"
    local wp_dir="$pics/Wallpaper"
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
        # No "version": the code owns that number, see bin/bhctl and Config.qml.
        printf '{\n  "theme": { "palette": "wallpaper", "accent": "blue" },\n  "wallpaper": { "folder": "%s", "current": "file://%s" }\n}\n' \
            "$wp_dir" "$wp_first" > "$CONFIG_HOME/buchhwin/shell.json"
        ok "settings seeded — scheme derived from $(basename "$wp_first")"
    else
        # No pictures anywhere. Everforest is the raft, not the destination:
        # a desktop with no colours at all is worse than a green one.
        printf '{\n  "theme": { "palette": "everforest-dark", "accent": "green" }\n}\n' \
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

    # ⚠️ TWO OF THE GENERATED FILES ARE NOT READ BY ANYBODY UNLESS SOMETHING
    # POINTS AT THEM, and for months nothing did.
    #
    # GTK finds gtk.css and settings.ini on its own. kitty and qt6ct do not:
    # kitty reads kitty.conf and only the files it `include`s, and qt6ct reads
    # qt6ct.conf and only the colour scheme named there. The renderer was
    # faithfully writing theme.conf and colors/buchhwin.conf into a void — so
    # the terminal sat at kitty's own black no matter which palette was chosen,
    # which is exactly how it was noticed.
    #
    # Seeded once, never overwritten: these are the user's files. If one exists
    # without the pointer, say so rather than editing it behind their back.
    if [[ ! -f "$CONFIG_HOME/kitty/kitty.conf" ]]; then
        printf '# buchhwin: colours, font and transparency come from theme.conf,\n# which is regenerated on every palette change. Your own settings go below.\ninclude theme.conf\n' \
            > "$CONFIG_HOME/kitty/kitty.conf"
        ok "kitty.conf seeded (includes the generated theme)"
    elif ! grep -q '^ *include  *theme\.conf' "$CONFIG_HOME/kitty/kitty.conf"; then
        warn "kitty.conf exists but does not 'include theme.conf' — the palette will not reach the terminal"
    fi

    if [[ ! -f "$CONFIG_HOME/qt6ct/qt6ct.conf" ]]; then
        printf '[Appearance]\ncustom_palette=true\ncolor_scheme_path=%s/qt6ct/colors/buchhwin.conf\nstyle=Fusion\nstandard_dialogs=default\n' \
            "$CONFIG_HOME" > "$CONFIG_HOME/qt6ct/qt6ct.conf"
        ok "qt6ct.conf seeded (selects the generated colours)"
    elif ! grep -q 'buchhwin\.conf' "$CONFIG_HOME/qt6ct/qt6ct.conf"; then
        warn "qt6ct.conf exists but does not select colors/buchhwin.conf — Qt apps keep their own colours"
    fi

    # ⚠️ WITHOUT THIS FILE THE LOCK SCREEN CANNOT CHECK A PASSWORD. PamContext
    # names a service in /etc/pam.d and there is no sensible fallback: a locker
    # that cannot authenticate is a locker you get out of with a TTY.
    #
    # Our own service rather than borrowing another program's. swaylock ships
    # /etc/pam.d/swaylock and it is tempting to point at it, but then locking
    # breaks the day swaylock is uninstalled — and it is not a dependency of
    # anything here. The shape is Fedora's own /etc/pam.d/vlock.
    if [[ ! -f /etc/pam.d/buchhwin-lock ]]; then
        sudo tee /etc/pam.d/buchhwin-lock >/dev/null <<'PAM'
#%PAM-1.0
# buchhwin lock screen. Same shape as Fedora's /etc/pam.d/vlock.
auth       include      system-auth
account    required     pam_permit.so
PAM
        ok "PAM service for the lock screen installed"
    else
        ok "PAM service for the lock screen already present"
    fi

    section "Theme"
    # FileView writes a file, it does not create the folder above it — and the
    # derived palette is the one generated file that is NOT in the repository.
    mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/buchhwin"

    step "rendering GTK, Qt, kitty and niri colours from the palette"
    # ⚠️ This also BUILDS the derived palette when the seed above chose it:
    # loading the "wallpaper" palette is what makes the shell read the image
    # and write the derived palette into XDG_STATE_HOME.
    run_tool render && ok "theme rendered"

    # The palette picker reads this instead of globbing at runtime.
    #
    # ⚠️ "wallpaper" is appended by hand rather than found by the listing: it is
    # the one palette that is generated and therefore does NOT live in this
    # folder. It used to, which meant a git pull could delete somebody's colour
    # scheme — see the note in shell/theme/Scheme.qml.
    ( cd "$REPO_DIR/shell/theme/palettes" && ls -1 ./*.json 2>/dev/null \
        | sed 's|^\./||; s|\.json$||' ) > "$REPO_DIR/shell/theme/palettes/index.txt"
    if [[ -f "${XDG_STATE_HOME:-$HOME/.local/state}/buchhwin/wallpaper.json" ]]; then
        echo wallpaper >> "$REPO_DIR/shell/theme/palettes/index.txt"
    fi

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
