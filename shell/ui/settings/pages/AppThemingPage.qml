// Other programs — one state each for the programs we colour.
//
// Three states per program, which is the brief: follow the scheme, a neutral
// grey, or leave the program alone entirely.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    readonly property var states: [
        { value: "inherit", label: "Follow" },
        { value: "colour",  label: "Colour" },
        { value: "neutral", label: "Neutral" },
        { value: "off",     label: "Off" }
    ]

    SettingGroup {
        Layout.fillWidth: true
        title: "Other programs"

        SettingRow {
            Layout.fillWidth: true
            key: "theming.enabled"
            label: "Theme other programs"
            hint: "Off leaves every foreign config alone and removes the files we wrote."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.mode"
            label: "Default state"
            hint: "What a program set to \"Follow\" does. Neutral is a grey scheme — themed but colourless; the semantic colours stay coloured."
            kind: "choice"
            choices: [
                { value: "colour",  label: "Colour" },
                { value: "neutral", label: "Neutral" },
                { value: "off",     label: "Off" }
            ]
            usable: Config.theming.enabled
        }

        // ⚠️ THIRTEEN ROWS, ONE PER PROGRAM, WRITTEN OUT. tools/render.qml reads
        // these with an explicit switch rather than `Config.theming[target]`, on
        // purpose, and a Repeater here would be the same shortcut on the other
        // side: the moment a name is added in one place and not the other, one
        // program stops being themed and nothing says so.
        //
        // ⚠️ AND THEY ARE ONE PER LINE BECAUSE THE TRIPWIRE COUNTS LINES.
        // Written compactly — `SettingRow { …; key: "theming.gtk"` — they were
        // still thirteen correct rows, and tests/setting-rows.sh reported
        // "55 rows, 42 keys": it anchors on `^ *key:` so that SettingRow's own
        // `property string key: ""` is not counted as a row. Keeping the check
        // strict and the markup plain is the right way round.
        SettingRow {
            Layout.fillWidth: true
            key: "theming.gtk"
            label: "GTK"
            hint: "⚠️ GTK reads our file once, at start. A running program keeps its colours until you restart it — light/dark and the icon theme do change live, because those go through gsettings."
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.qt"
            label: "Qt"
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.kitty"
            label: "kitty"
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.alacritty"
            label: "Alacritty"
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.niri"
            label: "niri"
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.btop"
            label: "btop"
            hint: "Ctrl+Shift+Escape opens it."
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.bat"
            label: "bat"
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.fastfetch"
            label: "fastfetch"
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.delta"
            label: "git-delta"
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.tmux"
            label: "tmux"
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.starship"
            label: "starship"
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.lazygit"
            label: "lazygit"
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theming.vscode"
            label: "VS Code"
            kind: "choice"
            choices: root.states
            usable: Config.theming.enabled
        }
    }
}
