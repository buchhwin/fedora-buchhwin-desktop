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
    for p in waybar alacritty fuzzel swaylock; do
        rpm -q "$p" >/dev/null 2>&1 && \
            warn "$p is installed (a weak dependency of niri). This desktop replaces it: sudo dnf remove $p"
    done

    sudo systemctl enable sddm.service >/dev/null 2>&1 || warn "could not enable sddm"
    ok "niri $(niri --version 2>/dev/null | head -1), quickshell $(qs --version 2>/dev/null | cut -d, -f1)"
}
