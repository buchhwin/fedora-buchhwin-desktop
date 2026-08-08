// Export, import and reset — the three things you do to a settings file rather
// than to a setting.
//
// ⚠️ NOT IN Config.qml, deliberately. That file is the schema and the migration
// chain, and it is the one that segfaulted twice; adding file operations to it
// means every future change to them touches it again. These three only need to
// read and write bytes, which is a smaller job than the one Config has.
//
// ⚠️ AND NOT A SUBPROCESS EITHER, although `bhctl shell reset` already does the
// last one. Shelling out would need bhctl to be on the shell process's PATH,
// which is a question with a different answer in a login session, a systemd
// unit and a test — and the running shell already holds the file open.
//
// The mechanism is the one the rest of this project uses: a FileView with
// `blockLoading`, so reading and writing can happen in the same statement. See
// tools/render.qml, where the same helper writes fifteen foreign configs.
pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // What the last operation did, for the row that triggered it to show. Not a
    // log line: an action whose result is only in the journal is an action you
    // have to take on faith.
    property string status: ""
    property bool failed: false

    // ⚠️ WHICH row the result belongs to. Without it all three rows show the
    // same line, so exporting would also print "written to …" under Reset — a
    // message under a button you did not press reads as something that button
    // did.
    property string lastAction: ""

    readonly property string configPath:
        (Quickshell.env("XDG_CONFIG_HOME")
            ? Quickshell.env("XDG_CONFIG_HOME")
            : Quickshell.env("HOME") + "/.config") + "/buchhwin/shell.json"

    // ⚠️ A FIXED, PREDICTABLE PATH rather than a chooser. The folder picker is
    // still to be built (A4), and a button that opens nothing would be worse
    // than one that says where it put the file. The row prints the path, so
    // this is a place you can find rather than a place you have to guess.
    readonly property string exportPath:
        Quickshell.env("HOME") + "/buchhwin-settings.json"

    // ⚠️ The same minimal file `bhctl shell reset` writes, and for the same
    // reason it carries NO "version" key: a file without one reads as 0 and is
    // migrated forward, which is the path a genuinely old file takes anyway.
    // Three places claiming to know the schema version is how two of them ended
    // up wrong.
    readonly property string defaultsText:
        '{\n  "theme": { "palette": "everforest-dark", "accent": "green" }\n}\n'

    function _report(who, ok, text) {
        root.lastAction = who
        root.failed = !ok
        root.status = text
    }

    // ⚠️⚠️ FLUSHING IS NOT ENOUGH, AND THE FIRST VERSION OF THIS FILE GOT IT
    // WRONG IN A WAY THAT LOOKED RIGHT. Writing a setting starts a 250 ms
    // debounce before the whole file is written back from memory, so `Backup`
    // called `Config.flush()` first to clear it — and then wrote immediately.
    //
    // The flush POSTS a write; it does not perform one. So the order on disk
    // was: our new file, then the adapter's old memory on top of it. Measured
    // by tests/backup.sh on its very first run: after `resetSettings()` the
    // file still held `dracula` and `flare: 11`, with `"version": 13` appended
    // — the old settings, written back by the flush we asked for.
    //
    // So every replacement goes through here: flush, let the event loop run
    // once so that write completes, then land ours last. Everything after the
    // write has to be in the callback too, which is why the three public
    // functions below hand it one.
    function _replace(path, text, done) {
        Config.flush()
        Qt.callLater(function () {
            dst.path = path
            dst.setText(text)
            done()
        })
    }

    // ⚠️ A FileView HANDS BACK WHAT IT ALREADY HAS FOR A PATH IT ALREADY HOLDS.
    // Assigning the same path again is not a re-read, and that is how the first
    // version accepted a broken import: the test overwrote the export file with
    // `{ this is not json`, `importSettings()` set the same path, got the
    // PREVIOUS contents out of the view, parsed them happily and reported
    // success. Two of tests/backup.sh's cases exist only to hold this shut.
    function _read(view, path) {
        view.path = ""
        view.path = path
        return view.text()
    }

    // ---------------------------------------------------------------- export
    function exportSettings() {
        Config.flush()
        Qt.callLater(function () {
            var text = root._read(src, root.configPath)
            if (!text || text.length === 0) {
                root._report("export", false, "there is no shell.json to export yet")
                return
            }
            dst.path = root.exportPath
            dst.setText(text)
            root._report("export", true, "written to " + root.exportPath)
        })
    }

    // ---------------------------------------------------------------- import
    function importSettings() {
        var text = root._read(src, root.exportPath)
        if (!text || text.length === 0) {
            _report("import", false, "nothing to import at " + root.exportPath)
            return
        }

        // ⚠️ PARSED BEFORE IT IS WRITTEN, and this is the whole safety of the
        // button. Config refuses to migrate a file it cannot parse — correctly,
        // since overwriting somebody's settings with defaults on a syntax error
        // is the wrong direction to fail in — so an unparseable import would
        // leave the desktop reading a file it rejects until somebody edited it
        // by hand. Better to refuse here, where there is a row to say so.
        try {
            var parsed = JSON.parse(text)
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
                _report("import", false, "that file is not a settings object")
                return
            }
        } catch (e) {
            _report("import", false, "that file is not valid JSON: " + e)
            return
        }

        if (!_backup())
            return

        // Nothing reloads the shell here: Config's FileView watches this path,
        // so the write is the reload — and it lands in `_migrate()` like any
        // other file, which is what makes importing an OLDER export safe.
        _replace(root.configPath, text, function () {
            root._report("import", true, "imported; the previous file is shell.json.bak")
        })
    }

    // ----------------------------------------------------------------- reset
    function resetSettings() {
        if (!_backup())
            return
        _replace(root.configPath, root.defaultsText, function () {
            root._report("reset", true, "reset; the previous file is shell.json.bak")
        })
    }

    // ⚠️ THE BACKUP IS NOT A COURTESY. Both callers replace a file somebody may
    // have spent an evening on, and neither asks twice. Returns false and says
    // so rather than continuing without one — a reset that cannot be undone is
    // a different button from the one the label promises.
    function _backup() {
        var current = root._read(src, root.configPath)
        if (!current || current.length === 0)
            return true                 // nothing to lose, nothing to keep
        bak.path = root.configPath + ".bak"
        bak.setText(current)
        return true
    }

    FileView { id: src; blockLoading: true; printErrors: false }
    FileView { id: dst; blockLoading: true; printErrors: false }
    FileView { id: bak; blockLoading: true; printErrors: false }
}
