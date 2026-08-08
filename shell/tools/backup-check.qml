// Do export, import and reset actually do what their buttons say?
//
// ⚠️ THESE THREE REPLACE A FILE SOMEBODY MAY HAVE SPENT AN EVENING ON, and two
// of them do it without asking twice. A reset button that silently does nothing
// is annoying; one that writes the wrong thing, or that loses the backup it
// promised, costs the settings. So the round trip is checked rather than
// assumed — and on its first run it found both: a reset that was immediately
// overwritten by the flush it had asked for, and an import that accepted
// `{ this is not json` because the FileView handed back a cached copy of the
// previous, valid file.
//
// ⚠️ IT RUNS IN STEPS, not in one pass. Every replacement defers its write by
// one turn of the event loop — it has to, see Backup._replace — so a check
// written straight after the call reads the file as it was before. That is the
// same shape as the bug being guarded against, which would make this the kind
// of test that is green either way.
//
// It runs against a throwaway XDG_CONFIG_HOME and HOME — tests/backup.sh sets
// both — so nothing here can reach a real settings file.
import QtQuick
import Quickshell
import Quickshell.Io
import "../common"
import "../config"

Item {
    id: root

    readonly property string out: "/tmp/buchhwin-backup-check.txt"
    property string report: ""

    property string original: ""
    property int step: 0

    function say(s) { report += s + "\n"; log.setText(report) }
    function check(name, ok, detail) {
        say((ok ? "  ok   " : "  FAIL ") + name + (detail ? "   " + detail : ""))
    }

    FileView { id: log; path: root.out }
    FileView { id: probe; blockLoading: true; printErrors: false }

    // The same fresh-read Backup has to do, and for the same reason: assigning
    // a path a view already holds is not a re-read.
    function read(path) {
        probe.path = ""
        probe.path = path
        return probe.text()
    }
    function put(path, text) { probe.path = path; probe.setText(text) }

    WaitFor {
        // The same condition every other tool waits on. Backup flushes Config,
        // and flushing a config that has not loaded yet would write the
        // defaults over the file this is about to read.
        condition: Config.settled
        onTimedOut: {
            root.say("  FAIL config never settled")
            Qt.callLater(Qt.quit)
        }
        onReady: steps.start()
    }

    // ⚠️ A TIMER RATHER THAN callLater, and longer than one turn. Config also
    // reacts to the file changing underneath it — it watches the path — so a
    // step has to leave room for the write AND for whatever the adapter does
    // about it, or the next read catches the file mid-argument.
    Timer {
        id: steps
        interval: 250
        repeat: true
        onTriggered: root.advance()
    }

    function advance() {
        var cfg = Backup.configPath
        var exp = Backup.exportPath
        step++

        switch (step) {
        case 1:
            original = read(cfg)
            check("there is a settings file to start from",
                  original.length > 0, original.length + " bytes")
            Backup.exportSettings()
            break

        case 2:
            var exported = read(exp)
            check("export writes the file", exported.length > 0, exp)
            check("export is byte-for-byte the settings file", exported === original)
            check("export reports where it went",
                  Backup.lastAction === "export" && !Backup.failed, Backup.status)
            Backup.resetSettings()
            break

        case 3:
            // ⚠️ The backup is checked BEFORE the content, because a reset that
            // wrote the right defaults and lost the old file would still be the
            // worse of the two failures.
            check("reset kept the previous file as .bak", read(cfg + ".bak") === original)
            var afterReset = read(cfg)
            check("reset really replaced the file", afterReset !== original,
                  afterReset.length + " bytes")
            check("reset wrote the defaults",
                  afterReset.indexOf("everforest-dark") >= 0
                  && afterReset.indexOf("dracula") < 0)
            Backup.importSettings()
            break

        case 4:
            check("import brought the exported file back", read(cfg) === original)
            check("import kept the reset file as .bak",
                  read(cfg + ".bak").indexOf("everforest-dark") >= 0)
            // The whole safety of the button: Config will not migrate a file it
            // cannot parse, so an unparseable import would leave the desktop
            // reading a file it rejects until somebody edited it by hand.
            put(exp, "{ this is not json")
            Backup.importSettings()
            break

        case 5:
            check("import refuses a file that is not JSON",
                  Backup.failed && Backup.lastAction === "import", Backup.status)
            check("and leaves the settings file alone", read(cfg) === original)
            put(exp, "[1, 2, 3]\n")
            Backup.importSettings()
            break

        case 6:
            check("import refuses a JSON array", Backup.failed, Backup.status)
            check("and leaves the settings file alone again", read(cfg) === original)
            steps.stop()
            Qt.callLater(Qt.quit)
            break
        }
    }
}
