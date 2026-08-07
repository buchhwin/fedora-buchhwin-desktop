// System — keyboard, touchpad, mouse, windows, the programs a reference points
// at, what starts with the session, where the machine is, and the key bindings.
//
// ⚠️ EVERY VALUE HERE IS WRITTEN INTO THE GENERATED niri CONFIG — and it gets
// there on its own. services/Theming.qml fingerprints these values and runs the
// generator when any of them changes; niri watches its own config and reloads
// it. Measured on 07.08.2026: config.kdl was rewritten about two seconds after
// shell.json changed, with no command typed.
//
// ⚠️ A SHELL RESTART ALONE STILL DOES NOT, which is the trap that has cost this
// project half an hour more than once: `rsync` plus `systemctl --user restart`
// changes the code without changing any VALUE, so the fingerprint is the same
// and nothing regenerates. That is when `bhctl niri apply` is needed — after
// editing defaults in the source, not after moving a slider.
//
// The enum values are niri's, checked in its own wiki rather than remembered:
// accel-profile is adaptive or flat, scroll-method is no-scroll, two-finger,
// edge or on-button-down, click-method is button-areas or clickfinger
// (Configuration:-Input.md:236-252), and mod-key takes any real modifier —
// though its own note says you probably do not want Ctrl or Shift (:383).
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    Component.onCompleted: Services.Installed.scan()

    readonly property var accelProfiles: [
        { value: "adaptive", label: "Adaptive" },
        { value: "flat",     label: "Flat" }
    ]

    // The render nodes this machine actually has, labelled by their driver —
    // because "which of these is the NVIDIA" is the only question anybody has
    // when they look at /dev/dri. The empty entry comes first and is the
    // default: letting niri choose is right on every machine that is not a
    // hybrid laptop with an external monitor plugged in.
    readonly property var renderChoices: {
        var out = [{ value: "", label: "niri chooses" }]
        var d = Services.Installed.renderDevices
        for (var i = 0; i < d.length; i++)
            out.push({ value: d[i].path, label: d[i].driver ? d[i].driver : d[i].path })
        return out
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Keyboard"

        SettingRow {
            Layout.fillWidth: true
            key: "keys.mod"
            label: "Mod key"
            hint: "⚠️ niri's own note: not Ctrl or Shift — Ctrl is what programs use for their own shortcuts, and Shift is for typing."
            kind: "choice"
            choices: [
                { value: "Super", label: "Super" },
                { value: "Alt",   label: "Alt" },
                { value: "Mod3",  label: "Mod3" },
                { value: "Mod5",  label: "Mod5" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.keyboard.layout"
            label: "Layout"
            hint: "The xkb layouts this machine knows, read from its own rules file."
            kind: "pick"
            options: Services.Installed.keyboardLayouts
            placeholder: "de"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.keyboard.variant"
            label: "Variant"
            kind: "pick"
            options: Services.Installed.keyboardVariants
            placeholder: "none"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.keyboard.options"
            label: "XKB options"
            hint: "Comma-separated, e.g. compose:ralt."
            kind: "field"
            placeholder: "none"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.keyboard.repeatDelay"
            label: "Repeat delay"
            hint: "How long a key is held before it starts repeating."
            kind: "slider"
            from: 100; to: 1000; step: 10; unit: "ms"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.keyboard.repeatRate"
            label: "Repeat rate"
            kind: "slider"
            from: 5; to: 100; step: 1; unit: "/s"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Touchpad"

        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.tap"
            label: "Tap to click"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.dwt"
            label: "Disable while typing"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.naturalScroll"
            label: "Natural scrolling"
            hint: "The content follows your fingers."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.middleEmulation"
            label: "Middle click by both buttons"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.accelSpeed"
            label: "Pointer speed"
            kind: "slider"
            from: -1.0; to: 1.0; step: 0.05; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.accelProfile"
            label: "Acceleration"
            hint: "Flat disables pointer acceleration entirely."
            kind: "choice"
            choices: root.accelProfiles
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.scrollMethod"
            label: "Scroll method"
            kind: "choice"
            choices: [
                { value: "two-finger",     label: "Two finger" },
                { value: "edge",           label: "Edge" },
                { value: "on-button-down", label: "Button held" },
                { value: "no-scroll",      label: "None" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.touchpad.clickMethod"
            label: "Click method"
            hint: "Clickfinger counts fingers; button areas splits the bottom of the pad into left and right."
            kind: "choice"
            choices: [
                { value: "clickfinger",  label: "Count fingers" },
                { value: "button-areas", label: "Button areas" }
            ]
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Mouse"

        SettingRow {
            Layout.fillWidth: true
            key: "input.mouse.naturalScroll"
            label: "Natural scrolling"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.mouse.accelSpeed"
            label: "Pointer speed"
            kind: "slider"
            from: -1.0; to: 1.0; step: 0.05; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.mouse.accelProfile"
            label: "Acceleration"
            kind: "choice"
            choices: root.accelProfiles
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Focus"

        SettingRow {
            Layout.fillWidth: true
            key: "input.focusFollowsMouse"
            label: "Focus follows the pointer"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.warpMouseToFocus"
            label: "Pointer jumps to the focused window"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Windows"

        SettingRow {
            Layout.fillWidth: true
            key: "windows.noCsd"
            label: "No title bars"
            hint: "Asks every program to let the compositor draw the frame — and niri draws none. ⚠️ libadwaita header bars stay: they are program content, not decoration."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "windows.blurred"
            label: "Blur behind"
            hint: "App ids, separated by commas. Only worth it for windows transparent enough to show it."
            kind: "strings"
            placeholder: "kitty, org.gnome.Nautilus"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "windows.floating"
            label: "Open floating"
            kind: "strings"
            placeholder: "None"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "windows.blockFromScreencast"
            label: "Hide from screen sharing"
            kind: "strings"
            placeholder: "None"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Graphics"

        // ⚠️ A CLOSED LIST, NOT A FIELD WITH SUGGESTIONS — and it is the one row
        // in the window where that is the right way round. `niri validate`
        // accepts a device path that does not exist (measured on 26.04, with a
        // control: an invented KEY in the same block is rejected, a missing
        // DEVICE is not), and a config naming a device niri cannot open means
        // niri does not start. Everywhere else a typed value that this machine
        // does not have is merely wrong; here it costs the session, and a
        // "Not installed here" caption under a text box would be a warning
        // shown after the damage was already typed.
        //
        // ⚠️ AND IT IS NOT GATED ON THE NVIDIA MODULE, which was the first
        // idea and is worse: renderDevice is not an NVIDIA setting. Naming the
        // integrated card is legitimate, and a machine with two AMD GPUs has
        // the same question. The list itself is the guarantee — every entry is
        // a render node that exists here with a driver bound to it.
        //
        // The way out, if it is ever reached by editing shell.json by hand: a
        // TTY, clear gpu.renderDevice, `bhctl niri apply`. Also in docs/NIRI.md.
        SettingRow {
            Layout.fillWidth: true
            key: "gpu.renderDevice"
            label: "Render on"
            hint: "Which GPU niri draws with. On a hybrid laptop the external display sockets usually belong to the second card, so niri renders on the built-in one and copies each frame across for that screen — naming the second card here removes the copy, and costs battery, because that card then never idles."
            kind: "choice"
            choices: root.renderChoices
        }
    }

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
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Session"

        SettingRow {
            Layout.fillWidth: true
            key: "autostart"
            label: "Start with the session"
            hint: "Full paths, separated by commas. The polkit agent is here by default — without it, anything that asks for a password gets no dialogue."
            kind: "strings"
            placeholder: "Nothing"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "workspaces"
            label: "Named workspaces"
            kind: "strings"
            placeholder: "None"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Where this machine is"

        // Its own group rather than a line in "Session", because it is used by
        // two different things — the weather and the light/dark schedule — and
        // neither of them owns it.
        SettingRow {
            Layout.fillWidth: true
            key: "location.name"
            label: "Place"
            hint: "Guessed from the timezone until you say otherwise. The quick panel has a search that fills all three."
            kind: "field"
            placeholder: "Guessed from the timezone"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "location.lat"
            label: "Latitude"
            kind: "field"
            placeholder: "unset"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "location.lon"
            label: "Longitude"
            kind: "field"
            placeholder: "unset"
        }
    }

    // ⚠️ NOT A `SettingRow` EITHER, and `binds` is named in the exemption list
    // of tests/setting-rows.sh for it. Sixty-three bindings are a list with its
    // own view, and rebinding a key is its own tool — capture the key, choose
    // the action, report the clash. That is a step of its own, by his decision;
    // this is the half that can be built without it.
    BindsList { Layout.fillWidth: true }
}
