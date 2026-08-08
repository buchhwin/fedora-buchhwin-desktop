// Do the two new controls write what they say?
//
// ⚠️ EVERYTHING ELSE ABOUT THESE ROWS IS CHECKED BY READING, and reading cannot
// see this. tests/setting-rows.sh proves every row names a real key;
// tests/suggestions.sh proves every suggesting row has a source and that the
// source answers. Neither touches the part that actually changes the file:
// clicking a chip, clicking a suggestion, typing an argument.
//
// ⚠️ AND ONE OF THOSE THREE CARRIES A PROMISE THAT IS EASY TO BREAK AND SILENT
// WHEN IT IS. `programs.terminal` is ["kitty", "-e", "btop"] — a program and its
// arguments, in order. Picking a different terminal from the suggestions must
// keep the arguments. Lose them and the key binding still works, still spawns a
// terminal, and simply stops opening btop; nothing anywhere says why.
//
// It cannot be done with synthetic input: the settings window could not be
// driven with ydotool on the test machine at all — motion arrives, clicks and
// keystrokes do not — and a check that depends on that would be a check that
// silently stops running. So the row is built here and its control is called
// directly, which is the same path a click takes one function further down.
//
// Runs against a throwaway XDG_CONFIG_HOME; tests/row-writes.sh sets it.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../config"
import "../ui/settings"

Item {
    id: root

    readonly property string out:
        Quickshell.env("BUCHHWIN_ROWS_OUT") || "/tmp/buchhwin-row-write-check.txt"
    property string report: ""

    FileView { id: log; path: root.out }
    FileView { id: probe; blockLoading: true; printErrors: false }

    function say(s) { root.report += s + "\n"; log.setText(root.report) }
    function check(name, good, detail) {
        root.say((good ? "  ok   " : "  FAIL ") + name + (detail ? "   " + detail : ""))
    }

    // Read the settings file from disk rather than from Config, because "the
    // control changed a property in memory" is not the claim being tested.
    // ⚠️ A FileView hands back what it already holds for a path it already has,
    // so the path is cleared first — config/Backup.qml pays for that lesson in
    // full and this is the same trap.
    function fileList(path, dotted) {
        probe.path = ""
        probe.path = Quickshell.env("XDG_CONFIG_HOME") + "/buchhwin/shell.json"
        var text = probe.text()
        if (!text || !text.length)
            return null
        try {
            var node = JSON.parse(text)
            var parts = dotted.split(".")
            for (var i = 0; i < parts.length; i++) {
                if (node === null || node === undefined)
                    return null
                node = node[parts[i]]
            }
            return node
        } catch (e) {
            return null
        }
    }

    // ⚠️ WALKS TO THE CONTROL BY WHAT IT CAN DO, not by its type. The control
    // lives inside SettingRow's Loader, and matching on a component name would
    // go blind the day one of them is renamed — the same reasoning
    // tools/pages-check.qml gives for harvesting rows by their properties.
    function findFn(obj, fname, depth) {
        if (!obj || depth > 8)
            return null
        if (typeof obj[fname] === "function")
            return obj
        var kids = obj.children === undefined ? [] : obj.children
        for (var i = 0; i < kids.length; i++) {
            var hit = root.findFn(kids[i], fname, depth + 1)
            if (hit)
                return hit
        }
        var d = obj.data === undefined ? [] : obj.data
        for (var j = 0; j < d.length; j++) {
            if (d[j] !== undefined && kids.indexOf(d[j]) < 0) {
                var hit2 = root.findFn(d[j], fname, depth + 1)
                if (hit2)
                    return hit2
            }
        }
        // A Loader keeps its content in `item`, which is neither a child nor in
        // `data` — and every one of these controls is behind one.
        if (obj.item !== undefined && obj.item !== null)
            return root.findFn(obj.item, fname, depth + 1)
        return null
    }

    function same(a, b) {
        if (a === null || a === undefined || a.length !== b.length)
            return false
        for (var i = 0; i < b.length; i++)
            if (String(a[i]) !== String(b[i]))
                return false
        return true
    }

    Component {
        id: rowComp
        SettingRow {}
    }

    property var picksRow: null
    property var cmdRow: null
    property int step: 0

    Timer {
        id: steps
        interval: 300
        repeat: true
        onTriggered: root.advance()
    }

    WaitFor {
        condition: Config.settled
        onReady: steps.start()
        onTimedOut: {
            root.say("  FAIL config never settled")
            Qt.callLater(Qt.quit)
        }
    }

    function advance() {
        root.step++
        switch (root.step) {

        // ── picks: a suggestion goes in ─────────────────────────────────────
        case 1:
            root.picksRow = rowComp.createObject(root, {
                key: "windows.blurred",
                kind: "picks",
                options: ["probe-one", "probe-two"]
            })
            break

        case 2:
            var addTo = root.findFn(root.picksRow, "add", 0)
            if (!addTo) {
                root.check("picks: the control is reachable", false)
                root.step = 90
                break
            }
            root.check("picks: the control is reachable", true)
            addTo.add("probe-one")
            addTo.add("probe-two")
            break

        case 3:
            var got = root.fileList("", "windows.blurred")
            root.check("picks: both suggestions land in the file",
                       root.same(got, ["probe-one", "probe-two"]),
                       "windows.blurred = " + JSON.stringify(got))
            break

        case 4:
            // ⚠️ ADDING THE SAME THING TWICE MUST DO NOTHING. It is a set; a
            // duplicate app-id in a window rule is a rule written twice, and
            // the chip for it would have no single thing to remove.
            root.findFn(root.picksRow, "add", 0).add("probe-one")
            break

        case 5:
            var dup = root.fileList("", "windows.blurred")
            root.check("picks: a duplicate is refused",
                       root.same(dup, ["probe-one", "probe-two"]),
                       JSON.stringify(dup))
            break

        case 6:
            root.findFn(root.picksRow, "drop", 0).drop("probe-one")
            break

        case 7:
            var left = root.fileList("", "windows.blurred")
            root.check("picks: a chip removes exactly itself",
                       root.same(left, ["probe-two"]),
                       JSON.stringify(left))
            root.picksRow.destroy()
            break

        // ── command: the arguments survive ──────────────────────────────────
        case 8:
            Config.set("programs.terminal", ["kitty", "-e", "btop"])
            Config.flush()
            break

        case 9:
            root.cmdRow = rowComp.createObject(root, {
                key: "programs.terminal",
                kind: "command",
                options: ["alacritty", "foot"]
            })
            break

        case 10:
            var w = root.findFn(root.cmdRow, "write", 0)
            if (!w) {
                root.check("command: the control is reachable", false)
                root.step = 90
                break
            }
            root.check("command: the control is reachable", true)
            // Exactly what clicking the "alacritty" suggestion does: the new
            // program, the arguments box untouched.
            w.write("alacritty", "-e, btop")
            break

        case 11:
            var argv = root.fileList("", "programs.terminal")
            root.check("command: picking a program keeps its arguments",
                       root.same(argv, ["alacritty", "-e", "btop"]),
                       JSON.stringify(argv))
            break

        case 12:
            // ⚠️ ARGUMENTS WITH NO PROGRAM ARE DROPPED. A list starting with
            // "-e" makes niri look for a binary called "-e", and the key that
            // uses it fails at the moment it is pressed — long after the box
            // was emptied.
            root.findFn(root.cmdRow, "write", 0).write("", "-e, btop")
            break

        case 13:
            var empty = root.fileList("", "programs.terminal")
            root.check("command: no program means no argv at all",
                       root.same(empty, []),
                       JSON.stringify(empty))
            root.cmdRow.destroy()
            break

        default:
            steps.stop()
            Qt.callLater(Qt.quit)
        }
    }
}
