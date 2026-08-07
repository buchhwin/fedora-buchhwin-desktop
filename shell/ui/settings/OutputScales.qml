pragma ComponentBehavior: Bound

// Screen scaling — one block per monitor, and the only control in this window
// that is not a `SettingRow`.
//
// ⚠️ IT CANNOT BE ONE. `outputs` is a LIST OF OBJECTS, one per monitor, each
// carrying a mode, a scale, a transform and a position. A single dotted path
// cannot name "the scale of the screen you are looking at", so this is the
// exception, and tests/setting-rows.sh names `outputs` in its exemption list
// rather than letting a pattern excuse it.
//
// ⚠️ AND THERE IS NO AUTOMATIC MODE, WHICH IS THE WHOLE POINT. niri already
// guesses: "If scale is unset, niri will guess an appropriate scale based on the
// physical dimensions and the resolution of the monitor" (its own wiki,
// Configuration: Outputs.md:141, since 0.1.6). Measured on the test machine —
// 480x240 mm at 1920 px is about 102 dpi, and niri picks 1.0, which is right.
// A heuristic of ours beside that would be one automatic system fighting
// another, and the loser would be whichever ran last.
//
// So what he asked for — "die Automatik schlägt vor, und der Regler sticht sie;   english-ok: the brief, quoted
// sobald von Hand gestellt wurde, darf die Automatik nicht zurückdrehen" — needs  english-ok: the brief, quoted
// no code at all beyond a switch. The MARK for "set by hand" is the entry
// existing: no entry means niri decides, an entry with a scale means you did.
// One state, not a value plus a flag that can disagree with it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../common"
import "../../config"
import "../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space4

    function _entry(name) {
        var outs = Config.outputs
        if (!outs)
            return null
        for (var i = 0; i < outs.length; i++)
            if (String(outs[i].name) === name)
                return outs[i]
        return null
    }

    function _copy(o) {
        var c = {}
        for (var k in o)
            c[k] = o[k]
        return c
    }

    // Rebuild the whole list rather than editing in place: JsonAdapter hands
    // back a wrapper, and mutating that is the shape this project has watched
    // segfault.
    function _write(name, scale) {
        var outs = []
        var found = false
        var src = Config.outputs || []
        for (var i = 0; i < src.length; i++) {
            var o = root._copy(src[i])
            if (String(o.name) === name) {
                found = true
                if (scale === null)
                    delete o.scale
                else
                    o.scale = scale
                // ⚠️ Only the scale is removed, and the entry survives if it
                // carries anything else. Dropping the whole object would take a
                // mode or a position with it — a setting this window does not
                // show yet, silently deleted by a switch that says "scaling".
                var keys = Object.keys(o)
                if (keys.length <= 1 && keys[0] === "name")
                    continue
            }
            outs.push(o)
        }
        if (!found && scale !== null)
            outs.push({ name: name, scale: scale })
        Config.set("outputs", outs)
        Config.flush()
    }

    BarText {
        Layout.fillWidth: true
        text: "Screen scale"
        font.pixelSize: Theme.fontSizeSm
        font.weight: Theme.weightSemibold
        color: Theme.fgMuted
    }

    Repeater {
        model: Quickshell.screens

        ColumnLayout {
            id: block
            required property var modelData

            readonly property var entry: root._entry(String(block.modelData.name))
            readonly property bool manual: block.entry !== null
                                        && block.entry.scale !== undefined
                                        && block.entry.scale !== null

            Layout.fillWidth: true
            spacing: Theme.space1

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space3

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0      // literal-ok: absence of a gap — name and size are one block

                    BarText {
                        Layout.fillWidth: true
                        text: String(block.modelData.name)
                        color: Theme.fg
                    }
                    BarText {
                        Layout.fillWidth: true
                        // What niri is using right now, whether it chose it or
                        // you did. Without it the slider is a number with
                        // nothing to compare against.
                        text: block.modelData.width + " × " + block.modelData.height
                            + " px, niri is using " + block.modelData.devicePixelRatio + "×"
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                        wrapMode: Text.WordWrap
                    }
                }

                // ⚠️ THE GUARD IS IN THE TEXT, NOT ONLY IN `visible`. Written as
                // `visible: block.manual` with a bare `block.entry.scale`
                // underneath, this threw "Cannot read property 'scale' of null"
                // on every start where no monitor had a manual scale — which is
                // the default state, so: always. QML evaluates a binding whether
                // or not the item is visible, and all 24 test suites were green
                // while it did. It was one line in the journal and nothing else.
                BarText {
                    visible: block.manual
                    text: block.manual ? Number(block.entry.scale).toFixed(2) + "×" : ""
                    color: Theme.fgMuted
                }

                Toggle {
                    checked: block.manual
                    onToggled: function (v) {
                        // Switching to manual starts from what niri chose, so
                        // the first drag moves from where you already are
                        // rather than jumping.
                        root._write(String(block.modelData.name),
                                    v ? Number(block.modelData.devicePixelRatio) : null)
                    }
                }
            }

            LevelRow {
                Layout.fillWidth: true
                enabled: block.manual
                showValue: false
                value: block.manual
                    ? Math.max(0, Math.min(1, (Number(block.entry.scale) - 0.5) / 2.5))
                    : 0
                steps: 50
                onMoved: function (f) {
                    root._write(String(block.modelData.name),
                                Math.round((0.5 + f * 2.5) * 20) / 20)
                }
                onNudged: function (d) {
                    if (!block.manual)
                        return
                    root._write(String(block.modelData.name),
                                Math.max(0.5, Math.min(3.0,
                                    Number(block.entry.scale) + d * 0.05)))
                }
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        text: "Off means niri chooses, from the screen's physical size and resolution. "
            + "It is right on ordinary hardware; turn it on only when it is not."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }

    // ⚠️ THIS USED TO SAY "run `bhctl niri apply`", AND THAT WAS WRONG.
    // Measured on 07.08.2026: `outputs` is in services/Theming.qml's
    // fingerprint, and that watcher runs the niri generator as well as the
    // theme renderer — config.kdl was rewritten by itself about two seconds
    // after the file changed, with no command typed. niri watches its own
    // config, so the scale simply arrives.
    //
    // A warning telling you to do something unnecessary is worse than none: it
    // teaches you that the window does not finish its own job.
}
