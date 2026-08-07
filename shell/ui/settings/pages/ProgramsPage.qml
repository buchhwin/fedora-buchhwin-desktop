// Programs — which terminal, browser and editor the keys and the shell reach
// for, and how the terminal itself behaves.
//
// ⚠️ THESE ARE ARGUMENT LISTS, NOT COMMAND LINES. `@terminal` in a keybinding
// resolves through them, so an entry is a program followed by its arguments —
// which is why they are comma-separated rather than a single string.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    SettingGroup {
        Layout.fillWidth: true
        title: "Programs"

        // ⚠️ ARGUMENT LISTS, NOT COMMAND LINES. niri's `spawn` takes one string
        // per argument, so a whole command line in one string makes it look for
        // a binary with spaces in its name — and it fails with a message that
        // does not mention the real cause. A comma is the separator here for
        // exactly that reason.
        SettingRow {
            Layout.fillWidth: true
            key: "programs.terminal"
            label: "Terminal"
            hint: "Program and arguments, separated by commas."
            kind: "strings"
            placeholder: "kitty"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "programs.browser"
            label: "Browser"
            kind: "strings"
            placeholder: "brave-browser"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "programs.fileManager"
            label: "File manager"
            kind: "strings"
            placeholder: "nautilus"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "programs.editor"
            label: "Editor"
            kind: "strings"
            placeholder: "code"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "programs.imageViewer"
            label: "Image viewer"
            kind: "strings"
            placeholder: "loupe"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "programs.video"
            label: "Video player"
            kind: "strings"
            placeholder: "vlc"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Terminal"

        // ⚠️ These four are BEHAVIOUR, not colour, and they are the first of
        // their kind — see the note on `terminal` in config/Config.qml. They
        // are written into the file kitty already includes, so they arrive with
        // the palette rather than needing a second include.
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.cursorShape"
            label: "Cursor shape"
            kind: "choice"
            choices: [
                { value: "beam",      label: "Beam" },
                { value: "block",     label: "Block" },
                { value: "underline", label: "Underline" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.cursorBlinkInterval"
            label: "Cursor blink"
            hint: "Seconds. 0 stops it blinking."
            kind: "slider"
            from: 0; to: 2.0; step: 0.1; decimals: 1; unit: "s"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.cursorTrail"
            label: "Cursor trail"
            hint: "How many cells the cursor may fall behind before it catches up in one sweep. 0 is off — this is the animation, and it needs kitty 0.36 or newer."
            kind: "slider"
            from: 0; to: 10; step: 1
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.scrollbackLines"
            label: "Scrollback"
            hint: "Lines kept above the top of the window."
            kind: "slider"
            from: 1000; to: 100000; step: 1000
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.shellIntegration"
            label: "Shell integration"
            hint: "Lets kitty see where each command starts and ends — that is what makes jump-to-prompt work and what opens the scrollback pager at the right line instead of at the top."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.remoteControl"
            label: "Remote control"
            hint: "Turns on allow_remote_control AND listen_on together, which is what the ssh kitten needs — the predecessor called it the single biggest quality-of-life win when you live in SSH sessions. Either line alone does nothing."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.scrollbackPager"
            label: "Scrollback in a pager"
            hint: "Ctrl+Shift+H hands the scrollback to less rather than scrolling it in place."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "terminal.audibleBell"
            label: "Audible bell"
            hint: "Off. A terminal that beeps in an office is somebody else's problem."
        }
    }
}
