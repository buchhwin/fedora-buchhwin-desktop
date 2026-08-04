# Phase: services — four units, down from the previous project's thirteen.
# Everything else that used to need a daemon is inside the shell.
phase_services() {
    section "Services"
    local u="$CONFIG_HOME/systemd/user"
    mkdir -p "$u"

    cat > "$u/buchhwin-shell.service" <<UNIT
[Unit]
Description=buchhwin shell (quickshell)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/qs -c buchhwin
# A shell that dies takes the bar, the notch and every menu with it, so it
# comes back on its own — but not in a tight loop that would hide the cause.
Restart=always
RestartSec=2
StartLimitIntervalSec=60
StartLimitBurst=5
OnFailure=buchhwin-shell-failed.service

[Install]
WantedBy=graphical-session.target
UNIT

    # When the shell is dead, notify-send is useless: the notification server
    # IS the dead thing. A terminal always works.
    cat > "$u/buchhwin-shell-failed.service" <<UNIT
[Unit]
Description=Explain why the buchhwin shell stopped

[Service]
Type=oneshot
ExecStart=/usr/bin/kitty --title "buchhwin shell failed" -- \
    sh -c "journalctl --user -u buchhwin-shell -n 60 --no-pager; echo; echo 'Press enter to close.'; read _"
UNIT

    cat > "$u/buchhwin-clipboard.service" <<UNIT
[Unit]
Description=Clipboard history (cliphist)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=/bin/sh -c '/usr/bin/wl-paste --type text --watch /usr/bin/cliphist store'
Restart=always

[Install]
WantedBy=graphical-session.target
UNIT

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable buchhwin-shell.service buchhwin-clipboard.service >/dev/null 2>&1 \
        || warn "could not enable the user services (no session yet is normal)"
    ok "3 user units written and enabled"
}
