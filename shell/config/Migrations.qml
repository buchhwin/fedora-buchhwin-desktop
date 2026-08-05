pragma Singleton

// Numbered migrations for ~/.config/buchhwin/shell.json.
//
// This does NOT walk back the rule stated in Config.qml. Adding a key still
// needs nothing: the adapter default answers for it, and a file written last
// month keeps working. A migration is only for the two cases a default cannot
// cover — a key that was RENAMED, and a key that was REMOVED. In both, the old
// name is already sitting in somebody's file and only code can know what it
// meant.
//
// It runs on the RAW JSON, deliberately, and this is the part that is easy to
// get wrong: JsonAdapter drops every key it does not declare. So a migration
// reading through the adapter cannot see the old field it exists to rescue —
// by the time the adapter has parsed the file, the evidence is gone. Read the
// text, transform the object, write it back, and only then let the adapter look.
//
// The chain is almost empty on purpose. It is here before the first rename so
// that the first rename is not also the day we discover we need a mechanism.

import QtQuick
// `Singleton` is a Quickshell type, not a QtQuick one. Leaving this import out
// fails as "Singleton is not a type" — and, because both singletons here share
// one qmldir, it takes Config down with it and the whole desktop reports
// "Type Config unavailable" instead of naming the real file.
import Quickshell

Singleton {
    id: root

    // Must match Config's `version` default. A file with a lower number is
    // brought forward; a HIGHER number means the config was written by a newer
    // build than this one, which we must not "migrate" — see needed().
    readonly property int current: 4

    // step[n] upgrades a config at version n to version n+1.
    // Each is a pure function: take the parsed object, return it changed.
    readonly property var steps: [
        // 0 → 1: versioning introduced. Files written before this had no
        // `version` key at all and no renamed fields to repair, so there is
        // nothing to do but stamp them.
        function (cfg) {
            return cfg
        },

        // 1 → 2: `wallpaper.derive` removed.
        //
        // It named three modes ("none", "accent", "full") and only ever held
        // the first, because the decision it described is already made by
        // theme.palette: setting that to "wallpaper" derives the scheme from
        // the image, and anything else does not. Two keys for one decision can
        // disagree, and the one that loses is whichever the reader forgot.
        //
        // Deleting it is safe precisely because it did nothing. It still needs
        // a migration rather than a default, since the old key is already
        // sitting in files and JsonAdapter would otherwise carry it forward
        // for ever as a fossil nobody dares remove.
        function (cfg) {
            if (cfg.wallpaper && typeof cfg.wallpaper === "object")
                delete cfg.wallpaper.derive
            return cfg
        },

        // 2 → 3: `weather` became `location`.
        //
        // The place was stored under the one feature that happened to need it
        // first. It is a property of the machine — the weather wants it, and so
        // do sunrise/sunset for automatic light/dark and gammastep's night
        // light. Moving it is a RENAME, which is exactly what this chain is for:
        // the old key is already sitting in files, and only code can know that
        // `weather.lat` and `location.lat` mean the same thing.
        //
        // Anything already under `location` wins — a newer build may have
        // written it, and a migration must not undo that.
        function (cfg) {
            if (cfg.weather && typeof cfg.weather === "object") {
                if (!cfg.location || typeof cfg.location !== "object")
                    cfg.location = {}
                var w = cfg.weather
                if (cfg.location.name === undefined && w.name !== undefined)
                    cfg.location.name = w.name
                if (cfg.location.lat === undefined && w.lat !== undefined)
                    cfg.location.lat = w.lat
                if (cfg.location.lon === undefined && w.lon !== undefined)
                    cfg.location.lon = w.lon
                // No `source` is carried over: a place in this block IS the
                // answer you gave. The timezone guess is never written, so the
                // presence of a name is the whole distinction.
                delete cfg.location.source
                delete cfg.weather
            }
            return cfg
        },

        // 3 → 4: the `dock` block and `surfaces.dock` removed.
        //
        // They described a dock that does not exist — iconSize, pinned,
        // monitors, and a switch to turn the whole thing off — and not one key
        // of it was ever read, because the dock is M7. A setting that does
        // nothing is worse than a missing one: it is a promise, and the only
        // way to discover it was empty is to try it and watch nothing happen.
        //
        // They come back with the dock itself, and then they will mean
        // something. Until then they are removed rather than left as furniture,
        // which is the same judgement the plan makes about the predecessor's
        // dead `bar.*` keys and its `dock.height`.
        function (cfg) {
            delete cfg.dock
            if (cfg.surfaces && typeof cfg.surfaces === "object")
                delete cfg.surfaces.dock
            return cfg
        }
    ]

    function versionOf(cfg) {
        if (!cfg || typeof cfg !== "object")
            return 0
        var v = cfg.version
        return (typeof v === "number" && isFinite(v) && v >= 0) ? Math.floor(v) : 0
    }

    // Only true when there is work to do AND it is work we can do.
    function needed(cfg) {
        var v = versionOf(cfg)
        return v < root.current
    }

    // A config from the future is left strictly alone: downgrading by guesswork
    // would delete settings this build has never heard of. The caller should
    // say so rather than proceed quietly.
    function fromFuture(cfg) {
        return versionOf(cfg) > root.current
    }

    // Returns { ok, config, from, to, error }.
    // On any failure the ORIGINAL object comes back untouched — a half-migrated
    // config is worse than an old one.
    function migrate(cfg) {
        var from = versionOf(cfg)

        if (fromFuture(cfg))
            return { ok: false, config: cfg, from: from, to: from,
                     error: "config version " + from + " is newer than this build (" +
                            root.current + "); refusing to downgrade" }

        if (from === root.current)
            return { ok: true, config: cfg, from: from, to: from, error: "" }

        // Work on a copy so a throwing step cannot leave the caller holding a
        // partly-rewritten object.
        var out
        try {
            out = JSON.parse(JSON.stringify(cfg))
        } catch (e) {
            return { ok: false, config: cfg, from: from, to: from,
                     error: "config is not serialisable: " + e }
        }

        for (var v = from; v < root.current; v++) {
            var step = root.steps[v]
            if (typeof step !== "function")
                return { ok: false, config: cfg, from: from, to: v,
                         error: "no migration from version " + v }
            try {
                out = step(out)
            } catch (e2) {
                return { ok: false, config: cfg, from: from, to: v,
                         error: "migration " + v + "→" + (v + 1) + " failed: " + e2 }
            }
            if (!out || typeof out !== "object")
                return { ok: false, config: cfg, from: from, to: v,
                         error: "migration " + v + "→" + (v + 1) + " returned nothing" }
        }

        out.version = root.current
        return { ok: true, config: out, from: from, to: root.current, error: "" }
    }
}
