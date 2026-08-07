// Appearance — the biggest page, and the one the whole "one change, everywhere"
// promise hangs off. 55 rows: the palette and its accent, the wallpaper, shape,
// transparency, effects, type, the cursor, and one state per themed program.
//
// ⚠️ THE PALETTE LIST IS READ, NOT TYPED. There are eleven files in
// theme/palettes/ plus three the shell derives (wallpaper, custom, neutral), and
// the day a twelfth is added a typed list here would be a menu that is missing
// one. Services.Themes already builds exactly this list for the palette grid on
// Mod+Shift+A — the grid and this row are the same offer in two shapes, which is
// the point of both reading the same service.
//
// ⚠️ AND THE SCALE ROWS ARE NOT `SettingRow`s. `outputs` is a list of objects,
// one per monitor, so it cannot be one row with one path — see OutputScales.qml,
// which is also where the "niri decides / I decided" mark lives.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    // ⚠️ Nothing is listed until a page that needs the list is opened. An idle
    // desktop must not be running fc-list over 133 font families.
    Component.onCompleted: Services.Installed.scan()

    // The colour names every palette defines. From the palette schema, not from
    // memory: theme/palettes/*.json each carry all fourteen.
    readonly property var accents: [
        { value: "rosewater", label: "Rosewater" }, { value: "flamingo", label: "Flamingo" },
        { value: "pink",      label: "Pink" },      { value: "mauve",    label: "Mauve" },
        { value: "red",       label: "Red" },       { value: "maroon",   label: "Maroon" },
        { value: "peach",     label: "Peach" },     { value: "yellow",   label: "Yellow" },
        { value: "green",     label: "Green" },     { value: "teal",     label: "Teal" },
        { value: "sky",       label: "Sky" },       { value: "sapphire", label: "Sapphire" },
        { value: "blue",      label: "Blue" },      { value: "lavender", label: "Lavender" }
    ]

    readonly property var palettes: {
        var out = []
        for (var i = 0; i < Services.Themes.entries.length; i++)
            out.push({ value: Services.Themes.entries[i].name,
                       label: Services.Themes.entries[i].name })
        return out
    }

    // The four states one program can be in. `inherit` is not a fifth colour —
    // it means "whatever the group is set to", which is why it is the default
    // for all thirteen.
    readonly property var states: [
        { value: "inherit", label: "Follow" },
        { value: "colour",  label: "Colour" },
        { value: "neutral", label: "Neutral" },
        { value: "off",     label: "Off" }
    ]

    SettingGroup {
        Layout.fillWidth: true
        title: "Colours"

        SettingRow {
            Layout.fillWidth: true
            key: "theme.palette"
            label: "Palette"
            hint: "The three at the front are calculated: from the wallpaper, from your own colour, and grey."
            kind: "choice"
            choices: root.palettes
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.accent"
            label: "Accent"
            hint: "A colour name, not a colour — every palette answers to all fourteen, so switching palette keeps your choice."
            kind: "choice"
            choices: root.accents
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.customColor"
            label: "Your own colour"
            hint: "Used when the palette is set to \"custom\". A hex value like #7fbbb3."
            kind: "field"
            // The example you TYPE, not a colour anything is drawn in — a Theme
            // token here would show whatever palette is loaded and teach the
            // wrong format.
            placeholder: "#7fbbb3"   // literal-ok: an example of the format, not a colour in use
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.autoLight"
            label: "Light and dark"
            hint: "On a schedule, the light palette is used between the two times below. ⚠️ Nothing is written when it switches — a service that saved the palette every morning would destroy the dark one."
            kind: "choice"
            choices: [
                { value: "off",      label: "Always dark" },
                { value: "schedule", label: "On a schedule" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.lightPalette"
            label: "Light palette"
            kind: "choice"
            choices: root.palettes
            usable: Config.theme.autoLight === "schedule"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.lightFrom"
            label: "Light from"
            kind: "field"
            placeholder: "07:00"
            usable: Config.theme.autoLight === "schedule"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "theme.lightUntil"
            label: "Light until"
            kind: "field"
            placeholder: "19:00"
            usable: Config.theme.autoLight === "schedule"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Wallpaper"

        SettingRow {
            Layout.fillWidth: true
            key: "surfaces.wallpaper"
            label: "Draw the wallpaper"
            hint: "The shell draws it rather than a second daemon. Off leaves whatever the compositor puts there."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.folder"
            label: "Folder"
            hint: "Where Mod+Shift+W looks for pictures."
            kind: "field"
            placeholder: "~/Pictures/Wallpapers"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.current"
            label: "Current picture"
            hint: "A file:// address. Easier to choose with Mod+Shift+W."
            kind: "field"
            placeholder: "file:///…"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.monitors"
            label: "Screens"
            kind: "strings"
            placeholder: "Every screen"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Size and shape"

        // ⚠️ The one place the compositor's own scaling is set, and it is per
        // monitor rather than one number — see the file for why there is no
        // automatic mode.
        OutputScales { Layout.fillWidth: true }

        SettingRow {
            Layout.fillWidth: true
            key: "look.uiScale"
            label: "Interface scale"
            hint: "Multiplies our own grid and type together, on top of the screen scale above. The fine adjustment, not the 4K lever."
            kind: "slider"
            from: 0.75; to: 2.0; step: 0.05; decimals: 2; unit: "×"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.rounding"
            label: "Corner radius"
            hint: "Every other radius in the shell is a proportion of this one."
            kind: "slider"
            from: 0; to: 32; step: 1; unit: "px"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.borderWidth"
            label: "Window border"
            kind: "slider"
            from: 0; to: 8; step: 1; unit: "px"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.panelBorderWidth"
            label: "Panel edge"
            hint: "The optional rim on our own surfaces."
            kind: "slider"
            from: 0; to: 8; step: 1; unit: "px"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.gapsIn"
            label: "Gap between windows"
            kind: "slider"
            from: 0; to: 48; step: 1; unit: "px"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.gapsOut"
            label: "Gap at the screen edge"
            kind: "slider"
            from: 0; to: 64; step: 1; unit: "px"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Transparency"

        SettingRow {
            Layout.fillWidth: true
            key: "look.opacityActive"
            label: "Focused window"
            hint: "⚠️ Compositor opacity fades the TEXT as well, unlike a terminal's own background opacity. That is why the default is 0.95 and not lower."
            kind: "slider"
            from: 0.4; to: 1.0; step: 0.01; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.opacityInactive"
            label: "Unfocused window"
            kind: "slider"
            from: 0.4; to: 1.0; step: 0.01; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.opacityPanel"
            label: "Our own surfaces"
            hint: "The island, the panels, this window."
            kind: "slider"
            from: 0.3; to: 1.0; step: 0.01; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.opacityApp"
            label: "Themed programs"
            hint: "Written into the foreign config files, so it only reaches programs we theme."
            kind: "slider"
            from: 0.3; to: 1.0; step: 0.01; decimals: 2
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.opacityTerminal"
            label: "Terminal"
            hint: "The terminal's own background opacity, which leaves the text sharp — not the compositor's."
            kind: "slider"
            from: 0.2; to: 1.0; step: 0.01; decimals: 2
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Effects"

        SettingRow {
            Layout.fillWidth: true
            key: "look.blur"
            label: "Blur"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.blurPasses"
            label: "Blur passes"
            hint: "⚠️ Passes cost GPU, offset does not — niri's own documentation says so. Raise the offset first."
            kind: "slider"
            from: 1; to: 6; step: 1
            usable: Config.look.blur
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.blurOffset"
            label: "Blur offset"
            kind: "slider"
            from: 1; to: 12; step: 0.5; decimals: 1
            usable: Config.look.blur
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.blurNoise"
            label: "Blur noise"
            hint: "A little grain stops large blurred areas banding."
            kind: "slider"
            from: 0; to: 0.2; step: 0.01; decimals: 2
            usable: Config.look.blur
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.blurSaturation"
            label: "Blur saturation"
            kind: "slider"
            from: 0.5; to: 2.0; step: 0.05; decimals: 2
            usable: Config.look.blur
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.glass"
            label: "Glass sheen"
            hint: "The light lying over the top of a pane."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadows"
            label: "Shadows"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadowSoftness"
            label: "Shadow softness"
            kind: "slider"
            from: 0; to: 96; step: 1; unit: "px"
            usable: Config.look.shadows
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadowSpread"
            label: "Shadow spread"
            kind: "slider"
            from: 0; to: 24; step: 1; unit: "px"
            usable: Config.look.shadows
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadowOffsetY"
            label: "Shadow drop"
            kind: "slider"
            from: 0; to: 32; step: 1; unit: "px"
            usable: Config.look.shadows
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadowOpacity"
            label: "Shadow strength"
            kind: "slider"
            from: 0; to: 1.0; step: 0.05; decimals: 2
            usable: Config.look.shadows
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.shadowBehindWindow"
            label: "Shadow behind the window"
            hint: "Off, because a translucent window shows its own shadow through itself — measured on Nautilus, the interior went from (66,50,35) to (40,32,25)."
            usable: Config.look.shadows
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Type"

        SettingRow {
            Layout.fillWidth: true
            key: "look.fontUi"
            label: "Interface font"
            kind: "pick"
            options: Services.Installed.fonts
            placeholder: "Inter"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.fontMono"
            label: "Monospace font"
            hint: "Only the fixed-width families, asked of fontconfig rather than kept in a list here."
            kind: "pick"
            options: Services.Installed.monoFonts
            placeholder: "JetBrainsMono Nerd Font"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.fontIcon"
            label: "Icon font"
            hint: "⚠️ \"Material Icons Round\", not the Symbols name — the wrong one renders every icon as a box."
            kind: "pick"
            options: Services.Installed.fonts
            placeholder: "Material Icons Round"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "look.fontSize"
            label: "Font size"
            kind: "slider"
            from: 7; to: 18; step: 1; unit: "pt"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Pointer"

        SettingRow {
            Layout.fillWidth: true
            key: "cursor.theme"
            label: "Cursor theme"
            hint: "The themes on this machine — a directory under /usr/share/icons or ~/.icons that actually contains cursors."
            kind: "pick"
            options: Services.Installed.cursorThemes
            placeholder: "Adwaita"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "cursor.size"
            label: "Cursor size"
            kind: "slider"
            from: 12; to: 64; step: 1; unit: "px"
        }
    }

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
