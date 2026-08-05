pragma Singleton

// Google Calendar, over CalDAV, using the account you already added.
//
// The route here is not the obvious one, and the reason is measured rather than
// preferred. The obvious route is evolution-data-server, which is what GNOME
// uses. It cannot work from this shell:
//
//   $ busctl call … CalendarFactory OpenCalendar s "system-calendar"
//   ss "/org/gnome/evolution/dataserver/Subprocess/2505/2" …
//   $ busctl call … "/org/gnome/evolution/dataserver/Subprocess/2505/2" … GetObjectList
//   Call failed: Object does not exist at path "…/Subprocess/2505/2"
//
// EDS ties an opened calendar to the CALLING D-BUS CONNECTION. Every `busctl`
// invocation is a new connection, so the object is gone before it can be
// queried — and busctl is the only door available, because Quickshell 0.2.1
// ships no DBus module. Using EDS would mean a permanently running helper in C,
// with a build step, in a project that has none.
//
// So: gnome-online-accounts holds the account and hands out an OAuth token
// (ONE short call, nothing that can die under us), and this talks CalDAV to
// Google directly. Also measured: goa-daemon is already running, Google's
// endpoint is baked into GOA, and the scope GOA requests includes
// `.../auth/calendar` — read AND write. That is why creating an appointment
// here puts it on the phone.
//
// The token is held in memory only. It is a bearer credential with about an
// hour of life; writing it to disk would be writing a password to disk.

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    // ------------------------------------------------------------- interface
    readonly property bool available: root.accountPath.length > 0 && root.collection.length > 0

    // What to say when `available` is false. A calendar page that is simply
    // empty cannot be told apart from a calendar with nothing in it.
    property string status: "Kein Konto eingerichtet"

    property string accountName: ""      // the address, for display
    property string accountPath: ""      // GOA object path
    property string collection: ""       // CalDAV URL of the calendar
    property bool busy: false

    // Instances for the window that was last requested, already expanded.
    property var events: []

    // The day a new appointment should default to. Set by the calendar page
    // before it hands over, so "new appointment" means the day you were looking
    // at rather than today — which is almost never the day you meant.
    property date draftDate: new Date()

    readonly property string endpoint: "https://apidata.googleusercontent.com/caldav/v2/"

    signal changed()                     // something was written; reload

    // ---------------------------------------------------------------- token
    property string _token: ""
    property double _tokenUntil: 0       // epoch ms

    function _tokenValid() {
        return root._token.length > 0 && new Date().getTime() < root._tokenUntil
    }

    // Everything that needs the network goes through here, so there is exactly
    // one place that knows how a token is obtained and when it has gone stale.
    property var _pending: null
    function _withToken(fn) {
        if (root._tokenValid()) { fn(root._token); return }
        root._pending = fn
        tokenProc.command = ["busctl", "--user", "--json=short", "call",
                             "org.gnome.OnlineAccounts", root.accountPath,
                             "org.gnome.OnlineAccounts.OAuth2Based", "GetAccessToken"]
        tokenProc.running = true
    }

    Process {
        id: tokenProc
        stdout: StdioCollector {
            onStreamFinished: {
                var fn = root._pending
                root._pending = null
                try {
                    var j = JSON.parse(text)
                    root._token = String(j.data[0])
                    // Renew a minute early. A request that starts valid and
                    // finishes expired fails in a way that looks like a bug in
                    // the calendar rather than in the clock.
                    var secs = Number(j.data[1]) || 3600
                    root._tokenUntil = new Date().getTime() + (secs - 60) * 1000
                } catch (e) {
                    root._token = ""
                    root.status = "Kein Zugriffstoken von den Online-Konten"
                    return
                }
                if (fn) fn(root._token)
            }
        }
    }

    // -------------------------------------------------------------- account
    // Find a Google account that has the calendar switched on.
    function refreshAccount() {
        accounts.running = true
    }

    Process {
        id: accounts
        command: ["busctl", "--user", "--json=short", "call",
                  "org.gnome.OnlineAccounts", "/org/gnome/OnlineAccounts",
                  "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.accountPath = ""
                root.accountName = ""
                root.collection = ""

                var objs
                try {
                    objs = JSON.parse(text).data[0]
                } catch (e) {
                    root.status = "Online-Konten antworten nicht"
                    return
                }

                for (var path in objs) {
                    var ifaces = objs[path]
                    var acc = ifaces["org.gnome.OnlineAccounts.Account"]
                    if (!acc) continue
                    if (!ifaces["org.gnome.OnlineAccounts.OAuth2Based"]) continue

                    var provider = acc.ProviderType ? String(acc.ProviderType.data) : ""
                    if (provider !== "google") continue

                    // GOA states this as a NEGATIVE, and reading it as "is the
                    // calendar on" would enable exactly the accounts that have
                    // it switched off.
                    var off = acc.CalendarDisabled ? acc.CalendarDisabled.data : true
                    if (off === true) continue

                    root.accountPath = path
                    root.accountName = acc.PresentationIdentity
                                       ? String(acc.PresentationIdentity.data) : ""
                    break
                }

                if (!root.accountPath.length) {
                    root.status = "Kein Google-Konto mit eingeschaltetem Kalender"
                    return
                }
                root.status = "Kalender wird gesucht …"
                root._findCalendar()
            }
        }
    }

    // ------------------------------------------------------------ discovery
    // Google exposes the primary calendar of an account at
    // <endpoint><address>/events/. The principal is asked first anyway, because
    // an address that differs from the account id (an alias, a Workspace
    // domain) makes the guessed URL wrong — and the failure would be a calendar
    // that is simply always empty.
    function _findCalendar() {
        if (!root.accountName.length) {
            root.status = "Konto ohne Adresse"
            return
        }
        var guess = root.endpoint + encodeURIComponent(root.accountName) + "/events/"
        root._withToken(function (tok) {
            var x = new XMLHttpRequest()
            x.onreadystatechange = function () {
                if (x.readyState !== XMLHttpRequest.DONE) return
                if (x.status >= 200 && x.status < 300) {
                    root.collection = guess
                    root.status = ""
                    root.changed()
                } else if (x.status === 401) {
                    // The token was refused: drop it so the next attempt gets
                    // a fresh one instead of retrying with the same bad value.
                    root._token = ""
                    root.status = "Anmeldung abgelehnt — Konto neu verbinden"
                } else {
                    root.status = "Kalender nicht gefunden (HTTP " + x.status + ")"
                }
            }
            x.open("PROPFIND", guess)
            x.setRequestHeader("Authorization", "Bearer " + tok)
            x.setRequestHeader("Depth", "0")
            x.setRequestHeader("Content-Type", "application/xml; charset=utf-8")
            x.send('<?xml version="1.0" encoding="utf-8"?>' +
                   '<d:propfind xmlns:d="DAV:"><d:prop><d:displayname/></d:prop></d:propfind>')
        })
    }

    // --------------------------------------------------------------- reading
    // The events of one month, expanded.
    //
    // The window is padded by a week on each side: the grid shows the tail of
    // the previous month and the head of the next, and those cells have to
    // carry their dots too.
    property int _wantYear: 0
    property int _wantMonth: -1

    function loadMonth(year, month) {
        if (!root.available) return
        root._wantYear = year
        root._wantMonth = month
        // Coalesced on purpose. Stepping from August to December is four
        // property changes in as many milliseconds, and firing a request per
        // step would mean four round trips whose first three results are thrown
        // away — paid for in radio time, which on a laptop is paid for twice.
        coalesce.restart()
    }

    Timer {
        id: coalesce
        interval: 120
        onTriggered: {
            if (root._wantMonth < 0) return
            var from = new Date(root._wantYear, root._wantMonth, 1)
            from.setDate(from.getDate() - 7)
            var to = new Date(root._wantYear, root._wantMonth + 1, 1)
            to.setDate(to.getDate() + 7)
            root._load(from, to)
        }
    }

    function _load(from, to) {
        root.busy = true
        root._withToken(function (tok) {
            var x = new XMLHttpRequest()
            x.onreadystatechange = function () {
                if (x.readyState !== XMLHttpRequest.DONE) return
                root.busy = false
                if (x.status === 401) {
                    root._token = ""
                    root.status = "Anmeldung abgelehnt"
                    return
                }
                if (x.status < 200 || x.status >= 300) {
                    root.status = "Termine nicht abrufbar (HTTP " + x.status + ")"
                    return
                }
                root.status = ""
                root.events = root._readMultistatus(x.responseText, from, to)
            }
            x.open("REPORT", root.collection)
            x.setRequestHeader("Authorization", "Bearer " + tok)
            x.setRequestHeader("Depth", "1")
            x.setRequestHeader("Content-Type", "application/xml; charset=utf-8")
            x.send('<?xml version="1.0" encoding="utf-8"?>' +
                   '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">' +
                   '<d:prop><d:getetag/><c:calendar-data/></d:prop>' +
                   '<c:filter><c:comp-filter name="VCALENDAR">' +
                   '<c:comp-filter name="VEVENT">' +
                   '<c:time-range start="' + root._utcStamp(from) +
                   '" end="' + root._utcStamp(to) + '"/>' +
                   '</c:comp-filter></c:comp-filter></c:filter>' +
                   '</c:calendar-query>')
        })
    }

    function _utcStamp(d) {
        function p(n) { return n < 10 ? "0" + n : "" + n }
        return d.getUTCFullYear() + p(d.getUTCMonth() + 1) + p(d.getUTCDate()) +
               "T" + p(d.getUTCHours()) + p(d.getUTCMinutes()) + p(d.getUTCSeconds()) + "Z"
    }

    // The multistatus response, one <response> per event resource.
    //
    // Read with regular expressions rather than responseXML on purpose: the
    // document is namespaced three ways (DAV:, caldav, sometimes Google's own),
    // and QML's DOM makes namespace-aware traversal far more code than the two
    // things actually needed here — the href, the etag, and the iCalendar text.
    // The iCalendar itself is parsed properly, by services/Ical.qml.
    function _readMultistatus(xml, from, to) {
        var out = []
        var blocks = String(xml).split(/<[a-zA-Z0-9]*:?response[\s>]/)
        for (var i = 1; i < blocks.length; i++) {
            var b = blocks[i]
            var href = /<[a-zA-Z0-9]*:?href[^>]*>([\s\S]*?)<\/[a-zA-Z0-9]*:?href>/.exec(b)
            var etag = /<[a-zA-Z0-9]*:?getetag[^>]*>([\s\S]*?)<\/[a-zA-Z0-9]*:?getetag>/.exec(b)
            var data = /<[a-zA-Z0-9]*:?calendar-data[^>]*>([\s\S]*?)<\/[a-zA-Z0-9]*:?calendar-data>/.exec(b)
            if (!data)
                continue

            var ical = root._unescapeXml(data[1])
            var parsed = Ical.parse(ical)
            var instances = Ical.expand(parsed, from, to)
            for (var k = 0; k < instances.length; k++) {
                instances[k].href = href ? root._unescapeXml(href[1]).trim() : ""
                instances[k].etag = etag ? root._unescapeXml(etag[1]).trim() : ""
                out.push(instances[k])
            }
        }
        out.sort(function (a, b) { return a.start.getTime() - b.start.getTime() })
        return out
    }

    function _unescapeXml(s) {
        return String(s).replace(/&lt;/g, "<").replace(/&gt;/g, ">")
                        .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
                        .replace(/&amp;/g, "&")
    }

    // --------------------------------------------------------------- writing
    // Create an appointment. This is the call that ends up on the phone.
    function create(ev, done) {
        if (!root.available) { if (done) done(false, "Kein Kalender verbunden"); return }

        var uid = Ical.newUid()
        var body = Ical.build({ uid: uid, summary: ev.summary, location: ev.location,
                                start: ev.start, end: ev.end, allDay: ev.allDay,
                                stamp: new Date() })
        var url = root.collection + encodeURIComponent(uid) + ".ics"

        root._withToken(function (tok) {
            var x = new XMLHttpRequest()
            x.onreadystatechange = function () {
                if (x.readyState !== XMLHttpRequest.DONE) return
                if (x.status >= 200 && x.status < 300) {
                    root.changed()
                    if (done) done(true, "")
                } else if (x.status === 412) {
                    // If-None-Match refused it: something is already there.
                    if (done) done(false, "Termin gibt es schon")
                } else {
                    if (x.status === 401) root._token = ""
                    if (done) done(false, "Nicht gespeichert (HTTP " + x.status + ")")
                }
            }
            x.open("PUT", url)
            x.setRequestHeader("Authorization", "Bearer " + tok)
            x.setRequestHeader("Content-Type", "text/calendar; charset=utf-8")
            // Create, never overwrite. Without this a repeated press could
            // silently replace an appointment that happened to share a URL.
            x.setRequestHeader("If-None-Match", "*")
            x.send(body)
        })
    }

    // Delete one instance's resource. Guarded by the etag, so a resource that
    // changed on the phone since it was displayed is NOT deleted blind.
    function remove(ev, done) {
        if (!root.available || !ev.href || !ev.href.length) {
            if (done) done(false, "Kein Termin ausgewaehlt")
            return
        }
        var url = /^https?:/.test(ev.href)
                  ? ev.href : "https://apidata.googleusercontent.com" + ev.href

        root._withToken(function (tok) {
            var x = new XMLHttpRequest()
            x.onreadystatechange = function () {
                if (x.readyState !== XMLHttpRequest.DONE) return
                if (x.status >= 200 && x.status < 300) {
                    root.changed()
                    if (done) done(true, "")
                } else if (x.status === 412) {
                    if (done) done(false, "Termin wurde anderswo geaendert — neu laden")
                } else {
                    if (x.status === 401) root._token = ""
                    if (done) done(false, "Nicht geloescht (HTTP " + x.status + ")")
                }
            }
            x.open("DELETE", url)
            x.setRequestHeader("Authorization", "Bearer " + tok)
            if (ev.etag && ev.etag.length)
                x.setRequestHeader("If-Match", ev.etag)
            x.send()
        })
    }

    // ------------------------------------------------------------- helpers
    // The instances that fall on one day — what the page lists under the grid.
    //
    // The list is an ARGUMENT rather than read from `root.events` inside, so a
    // binding that calls this genuinely depends on the events and re-evaluates
    // when they arrive. Reading the property inside would have meant writing
    // `Calendar.events, Calendar.pickDay(…)` at every call site: a comma
    // expression whose only job is to create a dependency, which is a trick
    // that works until somebody tidies it away.
    function pickDay(list, year, month, day) {
        var dayStart = new Date(year, month, day, 0, 0, 0).getTime()
        var dayEnd = dayStart + 86400000
        var out = []
        if (!list) return out
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            if (!e || !e.start) continue
            var s = e.start.getTime()
            var t = e.end ? e.end.getTime() : s
            // An all-day event's DTEND is exclusive, so one ending exactly at
            // midnight belongs to the previous day, not to this one.
            if (s < dayEnd && t > dayStart)
                out.push(e)
        }
        return out
    }

    // ⚠️ NOT `pickDay(...).length > 0`, which is what this was first.
    //
    // The month grid asks this for all 42 cells. With a linear scan inside,
    // drawing one month cost 42 × every event — every time the events changed,
    // on a machine whose whole point is running on a battery. The set below is
    // built ONCE per load; each cell is then a lookup.
    readonly property var dayIndex: root._indexDays(root.events)

    function _dayKey(y, m, d) { return y + "-" + m + "-" + d }

    function _indexDays(list) {
        var idx = ({})
        if (!list) return idx
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            if (!e || !e.start) continue
            var d = new Date(e.start.getFullYear(), e.start.getMonth(), e.start.getDate())
            var last = e.end ? e.end.getTime() : e.start.getTime()
            // An all-day event's DTEND is exclusive: one ending exactly at
            // midnight must not light up the following day.
            var guard = 0
            while (d.getTime() < last || guard === 0) {
                idx[root._dayKey(d.getFullYear(), d.getMonth(), d.getDate())] = true
                d.setDate(d.getDate() + 1)
                // A malformed multi-year event must not turn this into a loop
                // that fills memory. 400 days is longer than any window shown.
                if (++guard > 400) break
            }
        }
        return idx
    }

    function anyOn(index, year, month, day) {
        return index ? index[root._dayKey(year, month, day)] === true : false
    }
}
