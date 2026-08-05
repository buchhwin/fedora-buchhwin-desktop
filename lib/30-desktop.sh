# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
# Phase: desktop — niri, quickshell and the handful of tools quickshell cannot
# replace. Weak dependencies are OFF on purpose; see packages/dnf-desktop.txt.
phase_desktop() {
    section "Desktop"
    mapfile -t pkgs < <(read_list dnf-desktop.txt)
    step "${#pkgs[@]} packages, without weak dependencies"
    dnf_install noweak "${pkgs[@]}" || die "desktop packages failed"

    # Measured on a real Fedora 44 VM: niri Recommends waybar/alacritty/fuzzel/
    # swaylock. If an earlier run pulled them in, say so — a second bar on
    # screen is confusing and the cause is invisible.
    #
    # ⚠️ alacritty is NOT on this list any more. It used to be, and correctly:
    # it arrived as somebody else's recommendation. It is now installed
    # deliberately as the second terminal and themed from the same tokens as
    # kitty, so warning about it would be warning about our own decision.
    for p in waybar fuzzel swaylock; do
        rpm -q "$p" >/dev/null 2>&1 && \
            warn "$p is installed (a weak dependency of niri). This desktop replaces it: sudo dnf remove $p"
    done

    # ---------------------------------------------------------- themed toolbox
    mapfile -t tools < <(read_list dnf-tools.txt)
    step "${#tools[@]} themed tools"
    dnf_install noweak "${tools[@]}" || warn "some themed tools failed"

    # ⚠️ THE TWO EXCEPTIONS, and they are exceptions on purpose.
    #
    # The plan says "not a single COPR", and starship and lazygit are the two
    # programs on the list that Fedora does not package at all — checked with
    # `dnf repoquery`, not assumed. He was asked and agreed to these two, on the
    # condition that a broken COPR is reported rather than silently leaving two
    # programs missing. `bhctl doctor` does that half; this half is the install.
    for copr in atim/starship atim/lazygit; do
        pkg="${copr#*/}"
        rpm -q "$pkg" >/dev/null 2>&1 && continue
        if sudo dnf copr enable -y "$copr" >/dev/null 2>&1; then
            dnf_install noweak "$pkg" >/dev/null 2>&1 \
                || warn "copr $copr is enabled but $pkg would not install"
        else
            warn "copr $copr did not resolve — $pkg is not installed (bhctl doctor will keep saying so)"
        fi
    done

    sudo systemctl enable sddm.service >/dev/null 2>&1 || warn "could not enable sddm"
    ok "niri $(niri --version 2>/dev/null | head -1), quickshell $(qs --version 2>/dev/null | cut -d, -f1)"
}
