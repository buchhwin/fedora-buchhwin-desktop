# shellcheck shell=bash
# Sourced by install.sh, never executed — so there is no shebang, and the
# directive above is how shellcheck is told which shell to assume.
# Phase: preflight — refuse early and clearly rather than half-installing.
phase_preflight() {
    section "Checking the system"

    [[ -r /etc/os-release ]] || die "no /etc/os-release — is this Fedora?"
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == "fedora" ]] || die "this installer is for Fedora, not '${ID:-unknown}'"
    (( ${VERSION_ID:-0} >= 44 )) || die "Fedora 44 or newer is required (found ${VERSION_ID:-?})"

    # ⚠️ The distribution test alone is not enough: an image-based Fedora still
    # reports ID=fedora, and the run would die at the first of ~40 dnf calls.
    [[ -e /run/ostree-booted ]] && die "image-based Fedora (rpm-ostree) is not supported"

    sudo -n true 2>/dev/null || sudo true || die "sudo is required"
    ping -c1 -W3 fedoraproject.org >/dev/null 2>&1 || warn "no route to fedoraproject.org"

    ok "Fedora ${VERSION_ID}, sudo available"
}
