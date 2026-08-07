// Motion — whether things move, and how quickly.
//
// ⚠️ ONE MULTIPLIER, NOT THREE DURATIONS, and that is a design decision rather
// than a shortcut. 120/200/320 ms is not three independent numbers: the fade is
// faster than the settle, which is what makes content appear to arrive INSIDE a
// shape rather than after it. Three separate settings would invite breaking that
// ratio; a multiplier cannot.
//
// It reaches niri's own window animations too, because tools/niri.qml generates
// those from the same three numbers — so this is the tempo of the whole desktop,
// not only of our surfaces. That half arrives on its own: services/Theming.qml
// fingerprints these values and runs the generator, and niri watches its own
// config. Measured: 200 ms became 100 ms about two seconds after the file
// changed, with nothing typed.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../common"
import "../../../config"
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    SettingGroup {
        Layout.fillWidth: true
        title: "Motion"

        SettingRow {
            Layout.fillWidth: true
            key: "look.profile"
            label: "Effects and motion"
            hint: "Minimal switches off every animation, the blur, the shadows and the glass sheen together — one setting for a machine that would rather have the frames."
            kind: "choice"
            choices: [
                { value: "full",    label: "Full" },
                { value: "minimal", label: "Minimal" }
            ]
        }
        SettingRow {
            Layout.fillWidth: true
            key: "motion.speed"
            label: "Speed"
            hint: "Higher is faster: 2× halves every duration. It does not reach zero — \"no motion at all\" is the setting above, and two ways to say one thing is how they end up disagreeing."
            kind: "slider"
            from: 0.25; to: 4.0; step: 0.05; decimals: 2; unit: "×"
            usable: Config.look.profile !== "minimal"
        }
    }

    BarText {
        Layout.fillWidth: true
        text: "Right now the three durations are " + Theme.durFast + ", " + Theme.durBase
            + " and " + Theme.durSlow + " ms — one curve, no overshoot anywhere."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }

    BarText {
        Layout.fillWidth: true
        // Measured, because the first version of this line said the opposite:
        // shell.json changes, the theming watcher notices within about two
        // seconds, the generator rewrites config.kdl and niri reloads it. 200 ms
        // became 100 ms with nothing typed.
        text: "niri's own window animations come from the same numbers, "
            + "and follow within a couple of seconds."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }
}
