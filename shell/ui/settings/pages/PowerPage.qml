// Power — when the screen goes off, when the session locks, when the machine
// sleeps, and what the lid does.
//
// ⚠️ EVERY DELAY COUNTS FROM THE START OF IDLE, not from the previous step. Four
// independent timers, the way Windows counts them, so "screen off after 5, lock
// after 6" is two numbers that can be read back rather than one number and an
// offset. 0 means never, everywhere.
//
// ⚠️ AND EVERY ONE OF THEM STOPS FOR AN IDLE INHIBITOR. A video player asking to
// keep the screen awake is honoured, which is the whole reason the protocol has
// inhibitors — without it this page is a machine for locking the screen during
// films.
//
// Battery and mains are separate throughout. They are the two situations where
// the right answer genuinely differs, and one shared number would be wrong in
// one of them permanently.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../common"
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    // Which column is doing anything right now, so the page is readable while
    // it is open rather than being two lists of numbers that look equally live.
    readonly property string nowOn:
        Services.Power.available
            ? (Services.Power.charging ? "mains" : "battery")
            : "mains"

    BarText {
        Layout.fillWidth: true
        text: Services.Power.available
              ? "Running on " + root.nowOn + " — "
                + Math.round(Services.Power.percent) + "%. "
                + "The " + root.nowOn + " numbers are the ones in effect."
              : "No battery on this machine, so the mains numbers are always the "
                + "ones in effect."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "On battery"

        SettingRow {
            Layout.fillWidth: true
            key: "power.screenOffBattery"
            label: "Turn the screen off after"
            hint: "Minutes of no input. 0 never turns it off. Moving the mouse or pressing a key brings it straight back."
            kind: "slider"
            from: 0; to: 60; step: 1
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.lockBattery"
            label: "Lock after"
            hint: "⚠️ Counted from the start of idle, not from the screen going off. A minute more than the screen delay turns 'I looked away' into a keypress instead of a password."
            kind: "slider"
            from: 0; to: 120; step: 1
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.suspendBattery"
            label: "Suspend after"
            hint: "The session is locked first, so opening the lid again asks for the password."
            kind: "slider"
            from: 0; to: 180; step: 5
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.lidClosedBattery"
            label: "When the lid closes"
            hint: "⚠️ Handled by logind, not by the shell — `bhctl power apply` writes it, and it takes effect after the next reboot or a restart of systemd-logind."
            kind: "choice"
            choices: [{ value: "suspend", label: "Suspend" },
                      { value: "lock",    label: "Lock only" },
                      { value: "ignore",  label: "Do nothing" }]
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "On mains"

        SettingRow {
            Layout.fillWidth: true
            key: "power.screenOffAc"
            label: "Turn the screen off after"
            hint: "Minutes of no input. 0 never turns it off."
            kind: "slider"
            from: 0; to: 120; step: 1
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.lockAc"
            label: "Lock after"
            hint: "0 never locks by itself. Mod+L always locks now."
            kind: "slider"
            from: 0; to: 180; step: 1
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.suspendAc"
            label: "Suspend after"
            hint: "0 by default, and deliberately: a machine that is plugged in is usually plugged in because something should keep running."
            kind: "slider"
            from: 0; to: 240; step: 5
            unit: "min"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.lidClosedAc"
            label: "When the lid closes"
            hint: "The same setting for a machine on mains — logind keeps the two apart, so a docked laptop can stay awake with the lid shut."
            kind: "choice"
            choices: [{ value: "suspend", label: "Suspend" },
                      { value: "lock",    label: "Lock only" },
                      { value: "ignore",  label: "Do nothing" }]
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Performance"

        SettingRow {
            Layout.fillWidth: true
            key: "power.profile"
            label: "Power profile"
            hint: "The three tuned-ppd offers on this machine. Balanced is the default; power saver caps the boost clocks, which is quieter and cooler."
            kind: "choice"
            choices: [{ value: "power-saver", label: "Power saver" },
                      { value: "balanced",    label: "Balanced" },
                      { value: "performance", label: "Performance" }]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.dimBeforeOff"
            label: "Dim shortly before the screen goes off"
            hint: "Half a minute of warning, and the level you had is restored the moment anything happens — not a fixed brightness, which would quietly overwrite yours."
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Battery warnings"

        SettingRow {
            Layout.fillWidth: true
            key: "power.warnAt"
            label: "Warn at"
            hint: "⚠️ Once per discharge, not once per reading — UPower reports every few seconds, and a warning that repeats is one you learn to ignore. Plugging in re-arms it."
            kind: "slider"
            from: 0; to: 50; step: 1
            unit: "%"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "power.criticalAt"
            label: "Warn urgently at"
            hint: "The second and last warning. Also once per discharge."
            kind: "slider"
            from: 0; to: 30; step: 1
            unit: "%"
        }
    }

    BarText {
        Layout.fillWidth: true
        text: "Idle is handled by the shell itself — Quickshell's IdleMonitor "
            + "over ext-idle-notify, the same protocol swayidle uses. The lid is "
            + "the one thing here logind owns, because it happens whether or not "
            + "the shell is running."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }
}
