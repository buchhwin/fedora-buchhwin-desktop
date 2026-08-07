# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
# Phase: fonts — two downloads, because they are the two things nobody packages
# for Fedora: the Nerd font, and the macOS-style pointer he asked for.
phase_fonts() {
    section "Fonts"
    local dir="$DATA_HOME/fonts/JetBrainsMonoNerdFont"
    if [[ -d "$dir" ]] && compgen -G "$dir/*.ttf" >/dev/null; then
        ok "JetBrainsMono Nerd Font already installed"
    else
        step "fetching JetBrainsMono Nerd Font"
        mkdir -p "$dir"
        local url=https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
        if curl -fsSL "$url" | tar -xJ -C "$dir" 2>/dev/null; then
            # The Windows-compatible variants are duplicates with different
            # metrics; keeping them makes fontconfig pick unpredictably.
            find "$dir" -name '*Windows*' -delete 2>/dev/null
            fc-cache -f "$dir" >/dev/null 2>&1
            ok "JetBrainsMono Nerd Font"
        else
            warn "could not fetch the Nerd Font; the mono font will fall back"
        fi
    fi
}

# ⚠️ PINNED TO A COMMIT AND CHECKED AGAINST A HASH, unlike the font above.
# A long-term setup may not contain a foreign source that can change under it
# silently — and this one is a pointer, which is on screen at all times.
#
# ⚠️ WHY NOT THE PACKAGE MANAGER: it is not in Fedora. Apple's own cursors are
# not redistributable, so McMojave-cursors is a free rebuild (GPL-3). His choice,
# by name, on 06.08.2026.
readonly MCMOJAVE_COMMIT=7d0bfc1f91028191cdc220b87fd335a235ee4439
readonly MCMOJAVE_SHA256=66150af26f6f6257c4b9160b47cb9569020482ef55ea05b819b14f0663621702

phase_cursors() {
    section "Cursors"
    local dir="$DATA_HOME/icons/McMojave-cursors"
    if [[ -d "$dir/cursors" ]] && compgen -G "$dir/cursors/*" >/dev/null; then
        ok "McMojave-cursors already installed"
        return 0
    fi

    step "fetching McMojave-cursors"
    local tmp
    tmp="$(mktemp -d)" || { warn "no temporary directory"; return 0; }
    local url="https://github.com/vinceliuice/McMojave-cursors/archive/$MCMOJAVE_COMMIT.tar.gz"

    if ! curl -fsSL -o "$tmp/mc.tar.gz" "$url"; then
        warn "could not fetch McMojave-cursors; Breeze_Dark stays the pointer"
        rm -rf "$tmp"; return 0
    fi

    # ⚠️ THE CHECK IS THE POINT, so a mismatch STOPS rather than warning and
    # carrying on. A tarball that is not the one this was written against is not
    # a slightly different cursor theme, it is an unknown archive being unpacked
    # into the home directory.
    local got
    got="$(sha256sum "$tmp/mc.tar.gz" | cut -d" " -f1)"
    if [[ "$got" != "$MCMOJAVE_SHA256" ]]; then
        warn "McMojave-cursors checksum mismatch — refusing to unpack"
        warn "  expected $MCMOJAVE_SHA256"
        warn "  got      $got"
        rm -rf "$tmp"; return 0
    fi

    # ⚠️ `dist/` IS COPIED, `install.sh` IS NOT RUN. The archive ships 60
    # prebuilt cursors, so there is nothing to build — and running a downloaded
    # script to move files we can move ourselves buys nothing and costs the one
    # guarantee the checksum just gave us.
    if tar xzf "$tmp/mc.tar.gz" -C "$tmp" \
       && [[ -d "$tmp/McMojave-cursors-$MCMOJAVE_COMMIT/dist" ]]; then
        mkdir -p "$DATA_HOME/icons"
        rm -rf "$dir"
        cp -r "$tmp/McMojave-cursors-$MCMOJAVE_COMMIT/dist" "$dir"
        ok "McMojave-cursors"
    else
        warn "McMojave-cursors archive did not contain dist/"
    fi
    rm -rf "$tmp"
}
