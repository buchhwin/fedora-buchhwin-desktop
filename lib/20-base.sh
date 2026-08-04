# Phase: base — the packages nothing else works without.
phase_base() {
    section "Base system"
    mapfile -t pkgs < <(read_list dnf-core.txt)
    step "${#pkgs[@]} packages"
    dnf_install weak "${pkgs[@]}" || die "base packages failed"
    ok "base system"
}
