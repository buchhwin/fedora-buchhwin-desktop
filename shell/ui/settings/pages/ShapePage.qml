// Size and shape — one number for the size of everything, the corner radius,
// the gaps, and the per-monitor scale.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

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
}
