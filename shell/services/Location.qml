pragma Singleton

// Where this machine is. Once, for everything that needs it.
//
// It started inside the weather, which was the wrong home: a location is a
// property of the computer, not of one feature. Three things want it already —
// the weather, the sunrise/sunset that will drive automatic light/dark
// (theme.lightPalette has been waiting for exactly that since M1), and
// gammastep's night light, which takes latitude and longitude as arguments.
//
// ⚠️ AND USUALLY IT NEEDS NO INPUT AT ALL. The system already knows roughly
// where it is: /usr/share/zoneinfo/zone1970.tab maps every timezone to
// coordinates, offline and always present. Europe/Berlin is +5230+01322.
//
// That guess is OFFERED, never asserted. A timezone names its REFERENCE city,
// not yours — somebody in Stuttgart would silently get Berlin's weather, which
// is the worst kind of wrong: plausible. So `source` records where the answer
// came from, the panel says "guessed from the timezone" while it is only a
// guess, and a timezone change may update a guess but must never overwrite
// something you confirmed.
//
// Automatic geolocation was measured and rejected. geoclue is installed, but
// its whitelist in /etc/geoclue/geoclue.conf admits only gnome-shell, phosh and
// friends — a system file would have to be edited before our user program could
// even ask — and it locates by IP through the Mozilla database whose service
// was discontinued. City accuracy at best: exactly what the timezone gives, but
// needing the network, and wrong behind a VPN.

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    // ⚠️ A GUESS IS NOT A SETTING, SO IT IS NEVER WRITTEN DOWN.
    //
    // The timezone guess used to be saved to shell.json on first run. Two
    // things were wrong with that, and the second one cost a debugging round:
    //
    //   * A file should record decisions, not assumptions. Writing the guess
    //     made it indistinguishable from an answer, one `source` field away.
    //   * Writing the config DURING STARTUP crashes quickshell. Measured, not
    //     guessed: a config already holding a guessed location rewrote it on
    //     every start and crashed eight times in three restarts; skipping the
    //     rewrite left exactly one crash — the single start that did write.
    //
    // So the guess lives in memory and is recomputed each start. It costs one
    // `timedatectl` and one file read, offline, and it is always current: a
    // laptop that crosses a border guesses the new place rather than carrying
    // last month's around. Only a DECISION is written, and decisions happen
    // when you click, long after the shell has finished starting.
    readonly property string name:
        Config.location.name.length ? Config.location.name : root._guessName
    readonly property real lat:
        Config.location.name.length ? Config.location.lat : root._guessLat
    readonly property real lon:
        Config.location.name.length ? Config.location.lon : root._guessLon

    // "" = nothing known · "timezone" = guessed · "manual" = you said so
    readonly property string source:
        Config.location.name.length ? "manual"
      : (root._guessName.length ? "timezone" : "")

    property string _guessName: ""
    property real _guessLat: NaN
    property real _guessLon: NaN

    readonly property bool known: root.name.length > 0 && !isNaN(root.lat)
    readonly property bool guessed: root.known && root.source !== "manual"

    // ⚠️ Every service carries `available`, and this one did not. The rule
    // exists so the ui can ASK rather than assume, and a service without it is
    // used as though it were always there — here that would mean the weather
    // and the sunrise schedule quietly working from a place of `NaN`. Missed
    // for a whole milestone because nothing checked; tests/smoke.sh does now.
    //
    // "Available" for a place means we have one at all, however we got it —
    // whether it was guessed or confirmed is a separate question, and that is
    // what `guessed` is for.
    readonly property bool available: root.known

    // The system's timezone, read rather than stored. A copy in our config
    // would drift, and then the clock and the weather would disagree about
    // which country this is.
    property string timezone: ""

    // --------------------------------------------------------------- guessing
    Process {
        id: tz
        command: ["timedatectl", "show", "-p", "Timezone", "--value"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.timezone = text.trim()
                zones.reload()
            }
        }
    }

    FileView {
        id: zones
        path: "/usr/share/zoneinfo/zone1970.tab"
        printErrors: false
        onLoaded: root._guessFromTimezone()
    }

    // ⚠️ ISO 6709, and this is where it is easy to be wrong: the fields have
    // FIXED WIDTH and longitude carries THREE degree digits, not two.
    //
    //   +5230+01322        52°30'      13°22'
    //   +404251-0740023    40°42'51"  -74°00'23"
    //
    // Reading it as "split on the sign and parse" gives Berlin a longitude of
    // 1°32', which is in the Channel.
    function parseIso6709(s) {
        var m = /^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/.exec(String(s).trim())
        if (!m)
            return null
        function deg(sign, d, mi, se) {
            var v = (+d) + (+mi) / 60 + (se ? (+se) / 3600 : 0)
            return sign === "-" ? -v : v
        }
        return { lat: deg(m[1], m[2], m[3], m[4]),
                 lon: deg(m[5], m[6], m[7], m[8]) }
    }

    // "Europe/Berlin" → "Berlin", "America/New_York" → "New York".
    function cityOf(zone) {
        var parts = String(zone).split("/")
        return parts[parts.length - 1].replace(/_/g, " ")
    }

    function _guessFromTimezone() {
        if (!root.timezone.length)
            return
        // Never override an answer the user gave. A laptop that crosses a
        // border must not silently relocate a place you typed in yourself.
        if (Config.location.name.length)
            return

        var lines = zones.text().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line.length || line.charAt(0) === "#")
                continue
            // country-codes <TAB> coordinates <TAB> zone <TAB> comment
            var f = line.split("\t")
            if (f.length < 3 || f[2] !== root.timezone)
                continue
            var c = root.parseIso6709(f[1])
            if (!c)
                return
            // In memory only — nothing is written until you decide something.
            root._guessName = root.cityOf(root.timezone)
            root._guessLat = c.lat
            root._guessLon = c.lon
            return
        }
    }

    // The one place the config is written, and it only ever runs from a click.
    // Deferred a step regardless: a write that lands inside the handler which
    // triggered it re-enters the config adapter, and that is not survivable.
    property var _pendingWrite: null

    function _write(name, lat, lon) {
        root._pendingWrite = { name: name, lat: lat, lon: lon }
        Qt.callLater(root._flush)
    }

    function _flush() {
        var w = root._pendingWrite
        if (!w)
            return
        root._pendingWrite = null
        Config.location.name = w.name
        Config.location.lat = w.lat
        Config.location.lon = w.lon
        Config.save()
    }

    // ---------------------------------------------------------------- search
    // Open-Meteo's geocoder: no API key, which is the only reason this can work
    // out of the box. A key would have to live either in this public repository
    // or in a setup step nobody completes.
    property var matches: []
    property bool searching: false
    property string status: ""

    property string _query: ""

    function search(text) {
        var q = String(text).trim()
        matches = []
        if (q.length < 3) {          // below three letters everything matches
            searching = false
            debounce.stop()
            return
        }
        root._query = q
        debounce.restart()
    }

    Timer {
        id: debounce
        // Typing "Frankfurt" is nine keystrokes and must not be nine requests.
        interval: 400
        onTriggered: {
            root.searching = true
            var x = new XMLHttpRequest()
            x.onreadystatechange = function () {
                if (x.readyState !== XMLHttpRequest.DONE) return
                root.searching = false
                if (x.status < 200 || x.status >= 300) {
                    root.status = "Place search is not reachable"
                    return
                }
                try {
                    var j = JSON.parse(x.responseText)
                    var out = []
                    var r = j.results || []
                    for (var i = 0; i < r.length && i < 5; i++)
                        out.push({ name: r[i].name,
                                   country: r[i].country || "",
                                   admin: r[i].admin1 || "",
                                   lat: r[i].latitude, lon: r[i].longitude })
                    root.matches = out
                    root.status = out.length ? "" : "No place found"
                } catch (e) {
                    root.status = "Place search returned nonsense"
                }
            }
            x.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=5&language=de&format=json&name="
                          + encodeURIComponent(root._query))
            x.send()
        }
    }

    // One write, and everything downstream follows — this start and the next.
    function choose(m) {
        root._write(m.name + (m.country && m.country.length ? ", " + m.country : ""),
                    m.lat, m.lon)
        root.matches = []
        root.status = ""
        root.confirmed()
    }

    // Confirm the guess as it stands: same effect as picking it from a list,
    // and it is the single click the whole design is built around.
    function confirm() {
        if (!root.known)
            return
        root._write(root.name, root.lat, root.lon)
        root.confirmed()
    }

    signal confirmed()
}
