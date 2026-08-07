pragma ComponentBehavior: Bound

// One setting, one row — and ONE path.
//
// ⚠️ THE `key` IS THE WHOLE DESIGN. A row does not get handed a value and a
// callback; it gets the dotted path of the setting and does both halves through
// it. That closes the failure tests/key-readers.sh cannot see: its subject is
// "a row that writes a key nothing reads is a switch that lies", and the other
// half of that sentence is a row that READS one key and WRITES another. Both
// would be real keys with real readers, the label would name one of them, and
// no text check anywhere could tell. With a single path there is nothing to get
// out of step.
//
// It is also what makes tests/setting-rows.sh possible: every row declares its
// key as a literal string, so the promise "every setting has a row" is
// countable rather than a thing somebody believes.
//
// ⚠️ THE ROW DOES NOT MOVE ITSELF. A switch shows `Config.get(key)`, and
// pressing it asks `Config.set` for a change. If the write is refused — an
// unknown path, a value the adapter will not take — the control stays where it
// was, which is the truth. A control that flips first and reconciles later is
// how you end up looking at a setting that is not set.
//
// Shape is from his reference: label at the left, value at the RIGHT of the same
// line in the form "14 px", the track full width underneath. Switches sit at the
// right-hand end of the label line. No dividing lines anywhere — rows are
// separated by space, which is rule three of the brief.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../config"
import "../../theme"

ColumnLayout {
    id: root

    // The dotted path into shell.json: "notch.flare", "input.touchpad.tap".
    property string key: ""
    property string label: ""
    // One short line under the label. Empty means no line — an explanation that
    // only repeats the label is noise with a smaller font.
    property string hint: ""

    // ⚠️ A STRING, NOT A QML ENUM, AND THE TRIPWIRE IS THE REASON. A typo in an
    // enum is caught by the engine but an enum cannot be grepped out of the
    // file; tests/setting-rows.sh checks the spelling of every `kind:` against
    // the five below, which catches the same typo AND keeps the row table
    // readable from outside QML.
    // switch | slider | choice | field | strings
    property string kind: "switch"

    // --- slider
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string unit: ""

    // --- choice: [{ value: "off", label: "Off" }, …]
    property var choices: []

    // --- field / strings: what an EMPTY value means. A blank box reads as
    // "unset", and for half these keys empty is a real answer with a meaning —
    // an empty monitor list is "every screen", not "no screens".
    property string placeholder: ""

    // Whether this row can do anything right now — a bar height while the bar
    // is switched off cannot. Dimmed rather than hidden: a setting you cannot
    // find is worse than one that is visibly inert, and hiding it would leave
    // the tripwire green while the promise was broken.
    property bool usable: true

    // ⚠️ Read through Config.get, not through a section alias, so that the path
    // in `key` is the only place the setting is named. Measured that a QML
    // binding does track a property read made by dynamic lookup inside a called
    // function, with the same value read directly as the control — so this
    // re-evaluates when the file changes underneath it.
    readonly property var current: root.key.length > 0 ? Config.get(root.key) : undefined

    readonly property real fraction: {
        var span = root.to - root.from
        if (span <= 0)
            return 0
        return Math.max(0, Math.min(1, (Number(root.current) - root.from) / span))
    }

    readonly property string valueText: {
        var v = root.current
        if (v === undefined || v === null)
            return ""
        var n = Number(v)
        if (isNaN(n))
            return String(v)
        return n.toFixed(root.decimals) + (root.unit.length > 0 ? " " + root.unit : "")
    }

    function _snap(raw) {
        var s = root.step > 0 ? root.step : 1
        var v = root.from + Math.round((raw - root.from) / s) * s
        return Math.max(root.from, Math.min(root.to, v))
    }

    // A `list<string>` comes back as a QJSValue wrapper rather than a JS Array —
    // Array.isArray() says false for it, which is why Config.program() walks it
    // by length and index too.
    function _listText(v) {
        if (v === undefined || v === null)
            return ""
        var out = []
        for (var i = 0; i < v.length; i++)
            out.push(String(v[i]))
        return out.join(", ")
    }

    function _textList(s) {
        var parts = String(s).split(",")
        var out = []
        for (var i = 0; i < parts.length; i++) {
            var p = parts[i].trim()
            if (p.length > 0)
                out.push(p)
        }
        return out
    }

    spacing: Theme.space1
    opacity: root.usable ? 1 : Theme.dimmed

    // ------------------------------------------------------------- label line
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space3

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0      // literal-ok: absence of a gap — label and its hint are one block

            BarText {
                Layout.fillWidth: true
                text: root.label
                color: Theme.fg
            }
            BarText {
                Layout.fillWidth: true
                visible: root.hint.length > 0
                text: root.hint
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }

        // The number, at the right-hand end of the label line, exactly as the
        // reference draws it.
        BarText {
            visible: root.kind === "slider"
            text: root.valueText
            color: Theme.fgMuted
        }

        Toggle {
            visible: root.kind === "switch"
            usable: root.usable
            checked: root.current === true
            onToggled: function (v) {
                Config.set(root.key, v)
                Config.flush()
            }
        }
    }

    // ----------------------------------------------------------- the control
    // ⚠️ `visible: active`, and it is load-bearing. A Loader with `active:
    // false` is zero pixels tall but STILL VISIBLE, and QtQuick.Layouts gives
    // every visible child its row spacing — ghost gaps, measured at 48 px where
    // 16 was meant. With eighteen rows on a page that is the difference between
    // a layout and a mess.
    Loader {
        Layout.fillWidth: true
        active: root.kind !== "switch"
        visible: active
        sourceComponent: root.kind === "slider" ? sliderControl
                       : root.kind === "choice" ? choiceControl
                       : root.kind === "strings" ? stringsControl
                       : root.kind === "field" ? fieldControl
                       : null
    }

    // ⚠️ `sourceComponent` needs a Component, never an instance. QML accepts an
    // instance without a word of complaint and then never builds the thing.
    Component {
        id: sliderControl

        LevelRow {
            enabled: root.usable
            value: root.fraction
            showValue: false
            // One notch per step, so the wheel walks the same values the track
            // can land on rather than a second, finer set of its own.
            steps: Math.max(1, Math.round((root.to - root.from) / (root.step > 0 ? root.step : 1)))
            onMoved: function (f) {
                Config.set(root.key, root._snap(root.from + f * (root.to - root.from)))
            }
            onNudged: function (d) {
                Config.set(root.key, root._snap(Number(root.current) + d * root.step))
            }
            // The end of a drag is a decision. Config.set only schedules a
            // write; this is what makes it land now rather than in 250 ms.
            onReleased: Config.flush()
        }
    }

    Component {
        id: choiceControl

        Flow {
            spacing: Theme.space2

            Repeater {
                model: root.choices

                Pill {
                    id: choicePill
                    required property var modelData

                    interactive: root.usable
                    active: String(root.current) === String(choicePill.modelData.value)

                    BarText {
                        text: choicePill.modelData.label !== undefined
                            ? choicePill.modelData.label : choicePill.modelData.value
                        color: choicePill.active ? Theme.accentFg : Theme.fg
                    }

                    onClicked: {
                        Config.set(root.key, choicePill.modelData.value)
                        Config.flush()
                    }
                }
            }
        }
    }

    // A comma-separated line for a `list<string>`.
    Component {
        id: stringsControl

        TextField {
            id: listField
            enabled: root.usable
            text: root._listText(root.current)
            placeholder: root.placeholder

            function commit() {
                Config.set(root.key, root._textList(listField.text))
                Config.flush()
            }

            onAccepted: listField.commit()
            // Leaving the field is also a decision. Requiring Return is how a
            // typed value gets lost by clicking somewhere else.
            Connections {
                target: listField.input
                function onActiveFocusChanged() {
                    if (!listField.input.activeFocus)
                        listField.commit()
                }
            }
        }
    }

    Component {
        id: fieldControl

        TextField {
            id: plainField
            enabled: root.usable
            placeholder: root.placeholder
            text: root.current === undefined || root.current === null ? "" : String(root.current)

            function commit() {
                Config.set(root.key, plainField.text)
                Config.flush()
            }

            onAccepted: plainField.commit()
            Connections {
                target: plainField.input
                function onActiveFocusChanged() {
                    if (!plainField.input.activeFocus)
                        plainField.commit()
                }
            }
        }
    }
}
