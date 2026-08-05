pragma Singleton

// The weather, from Open-Meteo.
//
// Chosen because it needs no API key. That is not a convenience — a key would
// have to live either in this public repository, where it would be revoked, or
// in a setup step nobody would complete. A service that works the moment you
// type a town name is the only kind that gets used.
//
// Two requests, both plain HTTPS:
//
//   geocoding-api.open-meteo.com/v1/search?name=…   town  → coordinates
//   api.open-meteo.com/v1/forecast?latitude=…       coords → weather
//
// ⚠️ COORDINATES are stored, never the search term. A name is ambiguous
// (there are thirty Springfields), it would have to be resolved again on every
// start, and resolving it needs the network — so a laptop opening its lid in a
// tunnel would show no weather for a place it has known for months.
//
// Fetched hourly, and only when a place is set. Weather does not change faster
// than that, and this runs on a battery: a service that polls because polling
// is easy is exactly what the desktop is not allowed to do.

import QtQuick
import Quickshell
import "../config"

Singleton {
    id: root

    readonly property bool configured:
        Config.weather.name.length > 0 && !isNaN(Config.weather.lat)

    readonly property bool available: root.configured && root.temperature !== null

    property string place: Config.weather.name
    property var temperature: null        // °C, or null while unknown
    property int code: -1                 // WMO weather code
    property string status: ""            // why there is nothing, in one line
    property bool busy: false

    // ---------------------------------------------------------------- search
    // Results of the last town lookup: [{name, country, lat, lon}]
    property var matches: []
    property bool searching: false

    function search(text) {
        var q = String(text).trim()
        matches = []
        if (q.length < 3) {           // below three letters everything matches
            searching = false
            debounce.stop()
            return
        }
        root._query = q
        debounce.restart()
    }

    property string _query: ""

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
                    root.status = "Ortssuche nicht erreichbar"
                    return
                }
                try {
                    var j = JSON.parse(x.responseText)
                    var out = []
                    var r = j.results || []
                    for (var i = 0; i < r.length && i < 5; i++) {
                        out.push({ name: r[i].name,
                                   country: r[i].country || "",
                                   admin: r[i].admin1 || "",
                                   lat: r[i].latitude, lon: r[i].longitude })
                    }
                    root.matches = out
                    root.status = out.length ? "" : "Kein Ort gefunden"
                } catch (e) {
                    root.status = "Ortssuche lieferte Unsinn"
                }
            }
            x.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=5&language=de&format=json&name="
                          + encodeURIComponent(root._query))
            x.send()
        }
    }

    // Remember a place. One write, and everything else follows from it.
    function choose(m) {
        Config.weather.name = m.name + (m.country.length ? ", " + m.country : "")
        Config.weather.lat = m.lat
        Config.weather.lon = m.lon
        Config.save()
        root.matches = []
        root.temperature = null
        root.refresh()
    }

    function forget() {
        Config.weather.name = ""
        Config.save()
        root.temperature = null
        root.matches = []
    }

    // --------------------------------------------------------------- forecast
    function refresh() {
        if (!root.configured || root.busy)
            return
        root.busy = true
        var x = new XMLHttpRequest()
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return
            root.busy = false
            if (x.status < 200 || x.status >= 300) {
                root.status = "Wetter nicht abrufbar"
                return
            }
            try {
                var j = JSON.parse(x.responseText)
                var c = j.current
                if (!c) { root.status = "Antwort ohne Wetter"; return }
                root.temperature = c.temperature_2m
                root.code = c.weather_code !== undefined ? c.weather_code : -1
                root.status = ""
            } catch (e) {
                root.status = "Wetter lieferte Unsinn"
            }
        }
        x.open("GET", "https://api.open-meteo.com/v1/forecast"
                      + "?latitude=" + Config.weather.lat
                      + "&longitude=" + Config.weather.lon
                      + "&current=temperature_2m,weather_code&timezone=auto")
        x.send()
    }

    // Hourly, and only with a place set. `triggeredOnStart` gets the first
    // reading without a second code path for "the first time".
    Timer {
        interval: 3600000
        repeat: true
        running: root.configured
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ----------------------------------------------------------- description
    // WMO weather codes, in the words a person would use. Grouped rather than
    // enumerated: the difference between "slight" and "moderate" drizzle is not
    // something anybody needs from a panel they glance at.
    function describe(c) {
        if (c === 0) return "klar"
        if (c <= 2) return "leicht bewölkt"
        if (c === 3) return "bedeckt"
        if (c <= 48) return "Nebel"
        if (c <= 57) return "Niesel"
        if (c <= 67) return "Regen"
        if (c <= 77) return "Schnee"
        if (c <= 82) return "Schauer"
        if (c <= 86) return "Schneeschauer"
        if (c <= 99) return "Gewitter"
        return ""
    }

    // Every icon this service can return, in one place so tests/icons.sh can
    // find them. ⚠️ Without this the names would live only inside the function
    // below, where nothing checks them — the test scans for `icon…:` properties,
    // and a `return "wb_sunny"` is invisible to it. Half a tripwire is worse
    // than none, because it reads as full coverage.
    readonly property var iconNames: ["wb_sunny", "cloud", "grain", "ac_unit", "flash_on"]

    // An icon name that exists in Material Icons Round — checked by
    // tests/icons.sh, which measures them in the real font rather than trusting
    // that a plausible name is a real one.
    function icon(c) {
        if (c === 0) return "wb_sunny"
        if (c <= 3) return "cloud"
        if (c <= 48) return "cloud"
        if (c <= 67) return "grain"
        if (c <= 77) return "ac_unit"
        if (c <= 86) return "grain"
        return "flash_on"
    }

    readonly property string description: root.describe(root.code)
    readonly property string iconName: root.icon(root.code)
}
