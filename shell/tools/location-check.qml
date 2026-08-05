// Checks for the location layer: the coordinate format, and the migration.
//
//   BUCHHWIN_TOOL=location-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ ISO 6709 is where this goes wrong quietly. The fields have FIXED WIDTH and
// longitude carries THREE degree digits, not two. Read "+5230+01322" by
// splitting on the sign and parsing, and Berlin lands at 1°32' east — in the
// English Channel — with every downstream number still looking plausible.
import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services
import "../config"

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-location-check.txt" }
    function note(s) { report += s + "\n"; out.setText(report) }
    function near(what, got, want) {
        if (got !== null && Math.abs(got - want) < 0.02) note("  ok    " + what)
        else { failures++; note("  FAIL  " + what + "\n          got:  " + got +
                                "\n          want: " + want) }
    }
    function eq(what, got, want) {
        if (String(got) === String(want)) note("  ok    " + what)
        else { failures++; note("  FAIL  " + what + "\n          got:  " + got +
                                "\n          want: " + want) }
    }

    Timer {
        running: true
        interval: 200
        onTriggered: {
            note("buchhwin location-check")

            // ------------------------------------------------- ISO 6709
            var b = Services.Location.parseIso6709("+5230+01322")     // Europe/Berlin
            root.near("Berlin: Breite 52,50", b ? b.lat : null, 52.5)
            root.near("Berlin: Länge 13,37 (NICHT 1,53)", b ? b.lon : null, 13.3667)

            var n = Services.Location.parseIso6709("+404251-0740023") // America/New_York
            root.near("New York: Breite mit Sekunden", n ? n.lat : null, 40.7142)
            root.near("New York: Länge negativ", n ? n.lon : null, -74.0064)

            var s = Services.Location.parseIso6709("-3352+01825")     // Africa/Johannesburg
            root.near("Südhalbkugel: Breite negativ", s ? s.lat : null, -33.8667)

            root.eq("Unsinn wird abgelehnt",
                    Services.Location.parseIso6709("nicht-koordinaten"), null)

            // ------------------------------------------------- Stadtname
            root.eq("Europe/Berlin → Berlin",
                    Services.Location.cityOf("Europe/Berlin"), "Berlin")
            root.eq("America/New_York → New York",
                    Services.Location.cityOf("America/New_York"), "New York")
            root.eq("Argentina/Buenos_Aires (drei Ebenen)",
                    Services.Location.cityOf("America/Argentina/Buenos_Aires"),
                    "Buenos Aires")

            // ------------------------------------------------- Migration 2→3
            var old = { version: 2, weather: { name: "Passau, Deutschland",
                                               lat: 48.5667, lon: 13.4667 } }
            var r = Migrations.migrate(old)
            root.eq("Migration läuft durch", r.ok, true)
            root.eq("… weather ist weg", r.config.weather === undefined, true)
            root.eq("… der Ort ist übernommen", r.config.location.name, "Passau, Deutschland")
            root.near("… mit den Koordinaten", r.config.location.lat, 48.5667)
            root.eq("… ohne source-Feld (eine Vermutung wird nie geschrieben)",
                    r.config.location.source === undefined, true)
            root.eq("… Version steht auf 3", r.config.version, 3)

            // Ein schon vorhandener location-Block gewinnt.
            var both = { version: 2,
                         weather: { name: "Alt", lat: 1, lon: 2 },
                         location: { name: "Neu", lat: 3, lon: 4 } }
            var r2 = Migrations.migrate(both)
            root.eq("Ein vorhandener location-Block wird nicht überschrieben",
                    r2.config.location.name, "Neu")

            // Ohne Ort: kein erfundener.
            var empty = Migrations.migrate({ version: 2 })
            root.eq("Ohne weather entsteht kein Ort",
                    empty.config.location === undefined, true)

            note(root.failures === 0 ? "alles gruen"
                                     : root.failures + " Pruefung(en) fehlgeschlagen")
            Qt.callLater(Qt.quit)
        }
    }
}
