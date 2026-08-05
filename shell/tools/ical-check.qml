// Check the iCalendar reader against fixed samples.
//
//   BUCHHWIN_TOOL=ical-check QT_QPA_PLATFORM=offscreen qs -p shell
//
// The samples are inline rather than in files, so a case and the answer it is
// supposed to give sit on the same screen. Every one of them is a real shape
// Google sends: a timed event in a named zone, an all-day one, a weekly series,
// a monthly "last Friday", an excluded date, a moved instance.
//
// It also checks the month arithmetic the calendar page draws with, because
// "which day is the 1st on" is the other half of showing an event on the right
// day, and February 2100 is the case a hand-rolled leap year gets wrong.

import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services

Scope {
    id: root

    property string report: ""
    property int failures: 0

    function note(s) { report += s + "\n"; out.setText(report) }
    function ok(what) { note("  ok    " + what) }
    function bad(what, got, want) {
        failures++
        note("  FAIL  " + what + "\n          got:  " + got + "\n          want: " + want)
    }
    function eq(what, got, want) {
        if (String(got) === String(want)) ok(what)
        else bad(what, got, want)
    }

    FileView { id: out; path: "/tmp/buchhwin-ical-check.txt" }

    function pad(n) { return n < 10 ? "0" + n : "" + n }
    function stamp(d) {
        return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) +
               " " + pad(d.getHours()) + ":" + pad(d.getMinutes())
    }
    function stamps(list) {
        return list.map(function (e) { return stamp(e.start) }).join(" ")
    }

    // A Berlin VTIMEZONE exactly as Google writes it: last Sunday in March and
    // in October, given as rules rather than as offsets.
    readonly property string berlin:
        "BEGIN:VTIMEZONE\r\n" +
        "TZID:Europe/Berlin\r\n" +
        "BEGIN:DAYLIGHT\r\n" +
        "TZOFFSETFROM:+0100\r\nTZOFFSETTO:+0200\r\n" +
        "DTSTART:19700329T020000\r\n" +
        "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU\r\n" +
        "END:DAYLIGHT\r\n" +
        "BEGIN:STANDARD\r\n" +
        "TZOFFSETFROM:+0200\r\nTZOFFSETTO:+0100\r\n" +
        "DTSTART:19701025T030000\r\n" +
        "RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU\r\n" +
        "END:STANDARD\r\n" +
        "END:VTIMEZONE\r\n"

    function wrap(body) {
        return "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n" + berlin + body + "END:VCALENDAR\r\n"
    }

    Timer {
        running: true
        interval: 200
        onTriggered: {
            note("buchhwin ical-check")

            // ------------------------------------------------------ unfolding
            var folded = "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:a\r\n" +
                         "SUMMARY:Besprechung zum Quartals\r\n abschluss\r\n" +
                         "DTSTART:20260805T120000Z\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
            var f = Services.Ical.parse(folded)
            root.eq("gefaltete Zeilen werden zusammengesetzt",
                    f.events[0].summary, "Besprechung zum Quartalsabschluss")

            // --------------------------------------------------------- escapes
            var esc = Services.Ical.parse(
                "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:b\r\n" +
                "SUMMARY:Kaffee\\, Kuchen\\; und mehr\r\n" +
                "DTSTART:20260805T120000Z\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n")
            root.eq("Kommas und Semikolons werden entschluesselt",
                    esc.events[0].summary, "Kaffee, Kuchen; und mehr")

            // ------------------------------------------------------------ UTC
            var utc = Services.Ical.parse(wrap(
                "BEGIN:VEVENT\r\nUID:c\r\nDTSTART:20260805T120000Z\r\n" +
                "DTEND:20260805T130000Z\r\nSUMMARY:UTC\r\nEND:VEVENT\r\n"))
            root.eq("Z-Zeiten sind echte Zeitpunkte",
                    utc.events[0].start.getTime(),
                    Date.UTC(2026, 7, 5, 12, 0, 0))

            // ------------------------------------------- named zone, summer
            // 5 August is inside daylight saving: +0200, so 14:00 Berlin is
            // 12:00 UTC. Getting this wrong by an hour is the classic bug.
            var sum = Services.Ical.parse(wrap(
                "BEGIN:VEVENT\r\nUID:d\r\nDTSTART;TZID=Europe/Berlin:20260805T140000\r\n" +
                "DTEND;TZID=Europe/Berlin:20260805T150000\r\nSUMMARY:Sommer\r\nEND:VEVENT\r\n"))
            root.eq("Sommerzeit: 14:00 Berlin = 12:00 UTC",
                    sum.events[0].start.getTime(), Date.UTC(2026, 7, 5, 12, 0, 0))

            // ------------------------------------------- named zone, winter
            var win = Services.Ical.parse(wrap(
                "BEGIN:VEVENT\r\nUID:e\r\nDTSTART;TZID=Europe/Berlin:20260115T140000\r\n" +
                "SUMMARY:Winter\r\nEND:VEVENT\r\n"))
            root.eq("Winterzeit: 14:00 Berlin = 13:00 UTC",
                    win.events[0].start.getTime(), Date.UTC(2026, 0, 15, 13, 0, 0))

            // -------------------------------------------------------- all-day
            var all = Services.Ical.parse(wrap(
                "BEGIN:VEVENT\r\nUID:f\r\nDTSTART;VALUE=DATE:20260805\r\n" +
                "DTEND;VALUE=DATE:20260806\r\nSUMMARY:Geburtstag\r\nEND:VEVENT\r\n"))
            root.eq("ganztaegig bleibt auf seinem Tag",
                    stamp(all.events[0].start), "2026-08-05 00:00")
            root.eq("ganztaegig ist als solches erkannt", all.events[0].allDay, true)

            // ------------------------------------------------------- weekly
            // Every Wednesday from 5 August, five times.
            var wk = Services.Ical.parse(wrap(
                "BEGIN:VEVENT\r\nUID:g\r\nDTSTART;TZID=Europe/Berlin:20260805T100000\r\n" +
                "DTEND;TZID=Europe/Berlin:20260805T110000\r\n" +
                "RRULE:FREQ=WEEKLY;COUNT=5;BYDAY=WE\r\nSUMMARY:Jour fixe\r\nEND:VEVENT\r\n"))
            var wkx = Services.Ical.expand(wk, new Date(2026, 7, 1), new Date(2026, 8, 1))
            root.eq("woechentlich erscheint an JEDEM Termin, nicht einmal",
                    stamps(wkx),
                    "2026-08-05 10:00 2026-08-12 10:00 2026-08-19 10:00 2026-08-26 10:00")

            // -------------------------------------------------------- EXDATE
            var ex = Services.Ical.parse(wrap(
                "BEGIN:VEVENT\r\nUID:h\r\nDTSTART;TZID=Europe/Berlin:20260805T100000\r\n" +
                "DTEND;TZID=Europe/Berlin:20260805T110000\r\n" +
                "RRULE:FREQ=WEEKLY;BYDAY=WE\r\n" +
                "EXDATE;TZID=Europe/Berlin:20260812T100000\r\n" +
                "SUMMARY:Mit Ausfall\r\nEND:VEVENT\r\n"))
            var exx = Services.Ical.expand(ex, new Date(2026, 7, 1), new Date(2026, 7, 21))
            root.eq("ein ausgeschlossener Termin faellt weg",
                    stamps(exx), "2026-08-05 10:00 2026-08-19 10:00")

            // ------------------------------------------------- moved instance
            var mv = Services.Ical.parse(wrap(
                "BEGIN:VEVENT\r\nUID:i\r\nDTSTART;TZID=Europe/Berlin:20260805T100000\r\n" +
                "DTEND;TZID=Europe/Berlin:20260805T110000\r\n" +
                "RRULE:FREQ=WEEKLY;BYDAY=WE\r\nSUMMARY:Serie\r\nEND:VEVENT\r\n" +
                "BEGIN:VEVENT\r\nUID:i\r\n" +
                "RECURRENCE-ID;TZID=Europe/Berlin:20260812T100000\r\n" +
                "DTSTART;TZID=Europe/Berlin:20260812T160000\r\n" +
                "DTEND;TZID=Europe/Berlin:20260812T170000\r\n" +
                "SUMMARY:Serie verschoben\r\nEND:VEVENT\r\n"))
            var mvx = Services.Ical.expand(mv, new Date(2026, 7, 1), new Date(2026, 7, 21))
            root.eq("eine verschobene Einzelinstanz gewinnt",
                    stamps(mvx), "2026-08-05 10:00 2026-08-12 16:00 2026-08-19 10:00")
            root.eq("und traegt ihren eigenen Titel",
                    mvx.length > 1 ? mvx[1].summary : "-", "Serie verschoben")

            // ------------------------------------------- monthly, last Friday
            var mo = Services.Ical.parse(wrap(
                "BEGIN:VEVENT\r\nUID:j\r\nDTSTART;TZID=Europe/Berlin:20260828T090000\r\n" +
                "RRULE:FREQ=MONTHLY;BYDAY=-1FR\r\nSUMMARY:Monatsabschluss\r\nEND:VEVENT\r\n"))
            var mox = Services.Ical.expand(mo, new Date(2026, 7, 1), new Date(2026, 10, 1))
            root.eq("monatlich am LETZTEN Freitag",
                    stamps(mox), "2026-08-28 09:00 2026-09-25 09:00 2026-10-30 09:00")

            // -------------------------------------------------- write and read
            var made = {
                uid: "test-1@buchhwin", summary: "Zahnarzt, 2. Stock",
                start: new Date(Date.UTC(2026, 8, 3, 8, 30)),
                end: new Date(Date.UTC(2026, 8, 3, 9, 15)),
                allDay: false, stamp: new Date(Date.UTC(2026, 7, 5, 6, 0))
            }
            var back = Services.Ical.parse(Services.Ical.build(made))
            root.eq("was geschrieben wird, liest sich unveraendert zurueck (Titel)",
                    back.events[0].summary, "Zahnarzt, 2. Stock")
            root.eq("… und mit derselben Zeit",
                    back.events[0].start.getTime(), made.start.getTime())

            var madeAll = { uid: "test-2@buchhwin", summary: "Urlaub",
                            start: new Date(2026, 8, 3), allDay: true,
                            stamp: new Date(Date.UTC(2026, 7, 5, 6, 0)) }
            var text = Services.Ical.build(madeAll)
            root.eq("ganztaegig wird als DATE geschrieben",
                    text.indexOf("DTSTART;VALUE=DATE:20260903") >= 0, true)
            root.eq("… mit dem Folgetag als Ende (DTEND ist exklusiv)",
                    text.indexOf("DTEND;VALUE=DATE:20260904") >= 0, true)

            // ------------------------------------------------ month arithmetic
            // The same two numbers CalendarPage draws with. February 2100 is a
            // century that is NOT a leap year; 2400 is one that is.
            function leading(y, m) { return (new Date(y, m, 1).getDay() + 6) % 7 }
            function days(y, m) { return new Date(y, m + 1, 0).getDate() }

            root.eq("August 2026 beginnt an einem Samstag", leading(2026, 7), 5)
            root.eq("August 2026 hat 31 Tage", days(2026, 7), 31)
            root.eq("Februar 2028 hat 29 Tage (Schaltjahr)", days(2028, 1), 29)
            root.eq("Februar 2027 hat 28 Tage", days(2027, 1), 28)
            root.eq("Februar 2100 hat 28 Tage (Jahrhundert ohne Schaltjahr)", days(2100, 1), 28)
            root.eq("Februar 2400 hat 29 Tage (400er-Regel)", days(2400, 1), 29)
            root.eq("Februar 2032 beginnt an einem Sonntag", leading(2032, 1), 6)

            note(root.failures === 0 ? "alles gruen"
                                     : root.failures + " Pruefung(en) fehlgeschlagen")
            Qt.callLater(Qt.quit)
        }
    }
}
