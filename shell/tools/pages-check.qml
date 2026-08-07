// Build every settings page the window claims to have, and count the rows that
// actually come out.
//
//   BUCHHWIN_TOOL=pages-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ THIS IS THE HALF tests/setting-rows.sh CANNOT SEE. That check greps the
// page files for `key: "…"` lines and matches them against the schema, which is
// exactly the right question asked of the SOURCE. It cannot tell you whether the
// window ever builds the file: a page registered under a path that does not
// exist, or one that throws on creation, greps perfectly and draws nothing.
//
// The registration used to live in three places — the page list, a Component
// declaration, and a branch in a ten-way ternary — and forgetting the third
// produced precisely that: a page that loads, greps clean, and is blank. It is
// one place now, and this is the check that keeps it honest.
//
// It reads the list from SettingsContent itself rather than from the folder, so
// a page file that exists but is not registered is not counted as present, and
// a registered page whose file is gone is a failure rather than a silence.
//
// ⚠️ AND THE ROW COUNT IS A CROSS-CHECK, not decoration. setting-rows.sh counts
// rows by reading; this one counts them by building. The two disagreeing means a
// row is declared somewhere the window never instantiates — inside a Loader that
// is never active, or a component nothing reaches — which is the same class of
// fault as a key with no reader, one level up.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string report: ""
    property int failures: 0
    property int rowTotal: 0

    FileView { id: out; path: "/tmp/buchhwin-pages-check.txt" }
    function note(s) { root.report += s + "\n"; out.setText(root.report) }
    function ok(what, good) {
        if (good) root.note("  ok    " + what)
        else { root.failures++; root.note("  FAIL  " + what) }
    }

    // One frame, so the singletons exist before a page asks them anything. The
    // work is started FROM the timer, so there is nothing to race with.
    Timer {
        running: true
        interval: 250
        onTriggered: root.run()
    }

    // Walk an object tree and collect everything that looks like a settings row.
    //
    // ⚠️ IT ASKS FOR THE PROPERTIES, it does not match the type name. A row is a
    // row here because it carries `key` and `kind`, which is what the rest of the
    // system means by one — and a check that matched `SettingRow` by name would
    // go quietly blind the day somebody wraps one.
    function harvest(obj, into) {
        if (!obj)
            return
        if (obj.key !== undefined && obj.kind !== undefined && String(obj.key).length)
            into.push({ key: String(obj.key),
                        label: String(obj.label === undefined ? "" : obj.label) })

        // `children` is the visual tree; `data` also holds non-visual items. A
        // row inside a Repeater or an Instantiator hangs off the second one.
        var kids = obj.children === undefined ? [] : obj.children
        for (var i = 0; i < kids.length; i++)
            root.harvest(kids[i], into)
        var d = obj.data === undefined ? [] : obj.data
        for (var j = 0; j < d.length; j++)
            if (d[j] !== undefined && kids.indexOf(d[j]) < 0)
                root.harvest(d[j], into)
    }

    function run() {
        root.note("buchhwin pages-check")

        var shellComp = Qt.createComponent("../ui/settings/SettingsContent.qml")
        if (shellComp.status === Component.Error) {
            root.failures++
            root.note("  FAIL  SettingsContent does not compile:\n" +
                      String(shellComp.errorString()).replace(/^/gm, "          "))
            root.finish()
            return
        }
        var content = shellComp.createObject(root)
        if (content === null) {
            root.failures++
            root.note("  FAIL  SettingsContent does not build:\n" +
                      String(shellComp.errorString()).replace(/^/gm, "          "))
            root.finish()
            return
        }
        root.ok("SettingsContent builds", true)

        var pages = content.pages
        root.ok("it publishes a page list", pages !== undefined && pages.length > 0)
        if (!pages || !pages.length) {
            content.destroy()
            root.finish()
            return
        }
        root.note("  --    " + pages.length + " pages registered")

        var seen = {}
        for (var i = 0; i < pages.length; i++) {
            var p = pages[i]

            if (p.source === undefined || !String(p.source).length) {
                root.ok("\"" + p.id + "\" names a file", false)
                continue
            }
            if (seen[p.id] !== undefined) {
                root.ok("\"" + p.id + "\" is registered once", false)
                continue
            }
            seen[p.id] = true

            // The URL in the list is relative to the settings window's own
            // folder, which is where the Loader resolves it. Resolving it from
            // here has to say the same thing, hence the prefix rather than a
            // second spelling of the path.
            var c = Qt.createComponent("../ui/settings/" + p.source)
            if (c.status === Component.Error) {
                root.ok("\"" + p.id + "\" compiles", false)
                root.note("          " + String(c.errorString())
                                          .replace(/\n/g, "\n          "))
                continue
            }
            var page = c.createObject(root)
            if (page === null) {
                root.ok("\"" + p.id + "\" builds", false)
                root.note("          " + String(c.errorString()))
                continue
            }

            var rows = []
            root.harvest(page, rows)
            root.rowTotal += rows.length
            root.ok("\"" + p.id + "\" builds — " + rows.length + " rows", true)
            page.destroy()
        }

        content.destroy()
        root.note("  --    " + root.rowTotal + " rows built in total")
        root.finish()
    }

    function finish() {
        root.note(root.failures === 0
                  ? "pages-check: all good"
                  : "pages-check: " + root.failures + " check(s) failed")
        Qt.callLater(Qt.quit)
    }
}
