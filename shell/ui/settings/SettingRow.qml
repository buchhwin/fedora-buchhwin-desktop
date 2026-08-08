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
    // switch | slider | choice | field | strings | pick
    property string kind: "switch"

    // --- pick: the values this machine actually has. A `pick` is a text field
    // that SUGGESTS rather than a list that forbids — you can still type
    // something that is not installed yet, which matters for a config file that
    // may be copied to another machine before that machine has the font.
    property var options: []

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

    // ⚠️ THE NAME IS THE KEY, and it is how the search finds this row again
    // after navigating to its page. Rows only exist once their page is built,
    // so there is nothing to hold on to between "you searched for blur" and
    // "the Effects page has finished loading" except a string.
    objectName: root.key

    // Being found should be visible. Landing on a page of seventeen rows with
    // the right one somewhere in it is barely better than not searching — so
    // the row says which one it is, once, and then stops.
    property bool found: false
    function flash() {
        root.found = true
        forget.restart()
    }
    Timer {
        id: forget
        interval: Theme.durSlow * 6
        onTriggered: root.found = false
    }

    // ⚠️ THE LABEL CHANGES COLOUR RATHER THAN GAINING A BACKGROUND. A Rectangle
    // here would be a LAYOUT ITEM — this root is a ColumnLayout, and anchoring a
    // child inside a layout is ignored with a warning — so the highlight would
    // have appeared as an extra empty row pushing everything down. Colour costs
    // no space and cannot move anything.

    // ------------------------------------------------------------- label line
    RowLayout {
        id: labelLine
        Layout.fillWidth: true
        spacing: Theme.space3

        // ⚠️ THE WHOLE ROW IS THE TARGET FOR A SWITCH. It used to be the switch
        // itself — 44 x 24 px at the far right of a row several hundred wide.
        // Both references let you press anywhere on the row, and this shell has
        // already paid once for a hit area smaller than the thing it looked
        // like (the "every pill was half dead" bug, 68x29 lit and 44x21
        // answering).
        HoverHandler { id: rowHover }
        TapHandler {
            enabled: root.kind === "switch" && root.usable
            onTapped: {
                Config.set(root.key, !(root.current === true))
                Config.flush()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0      // literal-ok: absence of a gap — label and its hint are one block

            BarText {
                Layout.fillWidth: true
                text: root.label
                // Accent while the search has just brought you here, then back.
                // The fade out is the point: a highlight that stays is a row
                // that looks permanently special.
                color: root.found ? Theme.accent : Theme.fg
                font.weight: root.found ? Theme.weightSemibold : Theme.weightNormal

                Behavior on color {
                    enabled: Theme.animate
                    ColorAnimation { duration: Theme.durSlow; easing.type: Theme.easing }
                }
            }

            // ⚠️ ONE LINE, AND THE REST IN A TOOLTIP. These explanations are
            // mine and they are long; wrapped, almost every row was three lines
            // tall, and fifty-five of those is the wall he called hard to scan.
            //
            // ⚠️ AND IT IS ELIDED RATHER THAN HIDDEN ON HOVER. Showing it only
            // under the pointer would change the row's HEIGHT as the mouse
            // moves, so the page would shift under you while you read it. One
            // line always, the whole thing in a tooltip: no layout moves at all.
            BarText {
                id: hintLine
                Layout.fillWidth: true
                visible: root.hint.length > 0
                text: root.hint
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                elide: Text.ElideRight
                maximumLineCount: 1
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
                       : root.kind === "pick" ? pickControl
                       : null
    }

    // ⚠️ `sourceComponent` needs a Component, never an instance. QML accepts an
    // instance without a word of complaint and then never builds the thing.
    // The whole explanation, only while the pointer is on the row. It is the
    // same Tooltip the icon rail uses, so there is one definition of what a
    // tooltip looks like rather than two that drift.
    Tooltip {
        target: labelLine
        active: rowHover.hovered && hintLine.truncated
        text: root.hint
    }

    Component {
        id: sliderControl

        LevelRow {
            enabled: root.usable
            value: root.fraction
            showValue: false
            // ⚠️ NO WHEEL INSIDE A SCROLLING PAGE. LevelRow's handler covers the
            // whole row and accepts the event, so the settings page stopped
            // scrolling the moment the pointer crossed a slider — and every
            // notch it swallowed wrote a new value into the setting it was
            // passing over. Reported as the sliders being frozen; it was worse
            // than frozen.
            wheel: false
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

    // ⚠️ A FIELD WITH SUGGESTIONS, NOT A DROPDOWN. There are 133 font families
    // on the test machine and 99 keyboard layouts — as pills that is a wall, and
    // as a closed list it would refuse a name this machine does not have yet.
    // Typing filters; clicking picks; leaving it alone keeps what you typed.
    //
    // ⚠️⚠️ TWO FAULTS LIVED HERE AND TOGETHER THEY MADE EVERY LIST LOOK EMPTY.
    // He reported it as "wherever there should be a choice you cannot change
    // anything", and the service was innocent: a headless probe
    // (tools/installed-check.qml) reports 4 cursor themes, 109 fonts and 99
    // layouts on the same machine, at the same moment.
    //
    //   1. the suggestions were gated on `activeFocus`, so nothing was visible
    //      until the field already had the keyboard. You could not see that
    //      there WAS a choice, which is the one thing a list has to do.
    //   2. the field shows the current value, and that value was used as the
    //      search query. `cursor.theme` was "Breeze_Dark"; the four installed
    //      themes are Adwaita, Breeze_Light, McMojave-cursors, breeze_cursors —
    //      none of them contains that string. Zero matches, exactly when the
    //      list was needed most, and it got worse the more wrong the current
    //      value was.
    Component {
        id: pickControl

        ColumnLayout {
            id: pick
            spacing: Theme.space1

            readonly property string current:
                root.current === undefined || root.current === null ? "" : String(root.current)

            // How many pills to draw before saying "and N more". Eight was the
            // old cap and it is kept: it is about two rows, which is a list you
            // can read rather than a wall you scroll.
            readonly property int shown: 8

            readonly property var all: {
                var q = pickField.text.trim().toLowerCase()
                // ⚠️ THE QUERY IS EMPTY WHILE THE FIELD STILL SHOWS THE VALUE
                // IT WAS GIVEN. Anything else means the list filters itself by
                // the answer instead of by the question. Typing a single
                // character replaces it and filtering begins.
                if (q === pick.current.trim().toLowerCase())
                    q = ""
                var out = []
                for (var i = 0; i < root.options.length; i++) {
                    var o = String(root.options[i])
                    if (o.toLowerCase() === pick.current.trim().toLowerCase())
                        continue
                    if (q.length === 0 || o.toLowerCase().indexOf(q) >= 0)
                        out.push(o)
                }
                return out
            }
            readonly property var matches: pick.all.slice(0, pick.shown)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                TextField {
                    id: pickField
                    Layout.fillWidth: true
                    enabled: root.usable
                    text: pick.current
                    placeholder: root.placeholder

                    function commit() {
                        Config.set(root.key, pickField.text)
                        Config.flush()
                    }
                    onAccepted: pickField.commit()
                    Connections {
                        target: pickField.input
                        function onActiveFocusChanged() {
                            if (!pickField.input.activeFocus)
                                pickField.commit()
                        }
                    }
                }

                // Same reasoning as fieldControl above: nothing in this window
                // takes the keyboard away from a text field, so "commit when
                // you leave it" never happened. Clicking a suggestion already
                // commits — this is for a value typed by hand.
                Pill {
                    interactive: true
                    visible: pickField.text !== pick.current
                    active: true
                    BarText { text: "Apply"; color: Theme.accentFg }
                    onClicked: pickField.commit()
                }
            }

            // ⚠️ The one line that says the truth a text box cannot: the value
            // in the file is not on this machine. `cursor.theme` ships as
            // "Breeze_Dark" and the test machine has no such theme.
            BarText {
                Layout.fillWidth: true
                visible: root.options.length > 0 && pick.current.length > 0
                         && root.options.indexOf(pick.current) < 0
                text: "Not installed here"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.warn
            }

            Flow {
                Layout.fillWidth: true
                spacing: Theme.space2
                visible: pick.matches.length > 0

                Repeater {
                    model: pick.matches

                    Pill {
                        id: suggestion
                        required property var modelData
                        interactive: true
                        BarText { text: String(suggestion.modelData); color: Theme.fg }
                        onClicked: {
                            pickField.text = String(suggestion.modelData)
                            pickField.commit()
                        }
                    }
                }
            }

            // ⚠️ SAY WHAT IS NOT BEING SHOWN. With 109 fonts the eight pills
            // above are a sample, and a sample that does not admit it is a list
            // that looks complete and is not — the same fault as a check that
            // passes on an empty corpus. It also tells you what to do about it,
            // which "8 of 109" alone would not.
            BarText {
                Layout.fillWidth: true
                visible: pick.all.length > pick.matches.length
                text: "and " + (pick.all.length - pick.matches.length)
                      + " more — type to narrow it down"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
            }
        }
    }

    // ⚠️⚠️ AN APPLY BUTTON, BECAUSE LEAVING THE FIELD IS NOT AN EVENT HERE.
    // He reported "typing works but is not taken over", and the mechanism is
    // this: the only thing that committed a typed value was losing keyboard
    // focus, and in a window whose other controls are sliders and pills there
    // is nothing that TAKES focus — so the field keeps it until the window
    // closes, and closing destroys the value.
    //
    // Return still commits, and the focus-loss handler stays: it is correct
    // when it does fire, and removing it would break the one path that worked.
    // What is added is the thing he asked for in as many words — a button that
    // appears when there is something unsaved and goes away once there is not.
    // ⚠️ It is deliberately NOT always visible: a button that is present and
    // usually does nothing teaches people to ignore it, which is how the
    // refusal banner nearly went unread.
    Component {
        id: fieldControl

        RowLayout {
            spacing: Theme.space2

            readonly property string stored:
                root.current === undefined || root.current === null ? "" : String(root.current)

            TextField {
                id: plainField
                Layout.fillWidth: true
                enabled: root.usable
                placeholder: root.placeholder
                text: parent.stored

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

            Pill {
                interactive: true
                visible: plainField.text !== plainField.parent.stored
                active: true
                BarText { text: "Apply"; color: Theme.accentFg }
                onClicked: plainField.commit()
            }
        }
    }
}
