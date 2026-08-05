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
