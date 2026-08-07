// Mouse and touchpad — tapping, scrolling, and pointer speed.
//
// One page, because the two devices answer the same questions and the answers
// should be readable side by side. The mouse CURSOR is a different thing and
// lives with the fonts, where its size belongs.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    readonly property var accelProfiles: [
        { value: "adaptive", label: "Adaptive" },
        { value: "flat",     label: "Flat" }
    ]

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
            key: "input.touchpad.scrollFactor"
            label: "Scrolling speed"
            hint: "⚠️ There was no speed here at all — the schema had natural scroll, pointer acceleration and scroll method, so \"scrolling is too fast\" had no answer anywhere. 1.0 is niri's own; below 1 is slower."
            kind: "slider"
            from: 0.1; to: 3.0; step: 0.1; decimals: 1
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

        SettingRow {
            Layout.fillWidth: true
            key: "input.mouse.scrollFactor"
            label: "Scrolling speed"
            hint: "Separate from the touchpad's on purpose: a wheel notch and two fingers on glass are not the same gesture and almost never want the same number."
            kind: "slider"
            from: 0.1; to: 3.0; step: 0.1; decimals: 1
        }
    }
}
