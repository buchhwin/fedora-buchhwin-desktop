phase_summary() {
    section "Done"
    if (( WARNINGS )); then
        printf '  %s%s warning(s)%s — read them before rebooting.\n' "$C_WARN" "$WARNINGS" "$C_OFF"
    else
        printf '  no warnings.\n'
    fi
    cat <<'EOF'

  Reboot, then pick "niri" at the login screen.

    bhctl theme <palette> [accent]   switch colours (everything follows)
    bhctl doctor                     check the install, and list XWayland windows

EOF
}
