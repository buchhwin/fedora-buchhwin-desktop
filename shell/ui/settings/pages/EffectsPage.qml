// Effects — blur, shadows, and how much you can see through.
//
// Transparency and effects are one page because they are one question: what is
// drawn between a surface and what is behind it. They were two groups on a page
// with six others, which is how "the menus have a strange gradient" took a
// session to track down — the two halves of the answer were never on screen
// together.
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
}
