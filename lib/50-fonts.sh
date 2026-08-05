# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
# Phase: fonts — one download, because it is the one font nobody packages.
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
