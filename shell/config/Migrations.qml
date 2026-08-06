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
    readonly property int current: 8

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
        },

        // 4 → 5: `programs.launcher` removed.
        //
        // It was an empty argument list waiting for M6 to name some other
        // program to shell out to. M6 built the launcher instead, so the key
        // now describes a second launcher that nothing would ever start — the
        // same emptiness as the `dock` block above, and removed for the same
        // reason rather than left as furniture.
        //
        // ⚠️ Only the key goes. Somebody who put a real command in it was
        // asking for that program to be their launcher, and they lose that
        // here — which is why it is a migration with a note and not a silent
        // default change. The shell's own launcher is on Super+D.
        function (cfg) {
            if (cfg.programs && typeof cfg.programs === "object")
                delete cfg.programs.launcher
            return cfg
        },

        // 5 → 6: `keys.binds` moves to the top level as `binds`.
        //
        // ⚠️ THIS IS A CRASH FIX, NOT TIDYING. quickshell segfaulted on roughly
        // half of all starts, always with the same backtrace: QObjectWrapper::wrap
        // ← QMetaProperty::write ← JsonAdapter::deserializeRec, and the
        // deserializeRec frame appeared TWICE — a nested object. Bisected on the
        // machine, one key at a time, twelve runs each:
        //
        //   {"outputs":[ …objects… ]}            var, TOP LEVEL    0/12
        //   {"keys":{"binds":[ …objects… ]}}     var, NESTED       6/12
        //   {"windows":{"blurred":["kitty"]}}    list<string>      0/12
        //   {"keys":{"binds":[]}}                var, NESTED       6/12
        //
        // An EMPTY nested list is enough, so it is neither the length nor the
        // contents: writing a `var` property that sits inside a nested
        // JsonObject is what quickshell cannot survive. `binds` was the only one
        // in the whole config — every other list is a `list<string>` or
        // `list<int>`, and `outputs` is the one other `var` and is top level.
        //
        // Moving it up is therefore the whole fix, and it costs a migration
        // rather than a workaround that would have to be remembered.
        function (cfg) {
            if (cfg.keys && typeof cfg.keys === "object"
                && cfg.keys.binds !== undefined) {
                // The file wins over anything already at the top level: it is
                // where the user's bindings actually were.
                cfg.binds = cfg.keys.binds
                delete cfg.keys.binds
            }
            return cfg
        },

        // 6 → 7: the window shadow's three numbers were too small to be seen.
        //
        // ⚠️ THE FIRST MIGRATION IN THIS CHAIN THAT IS NEITHER A RENAME NOR A
        // REMOVAL, and it needs to exist for a reason the header does not
        // cover: JsonAdapter writes every key it knows into shell.json, so the
        // OLD default is already sitting in the file on every machine that has
        // ever started this shell. Changing the default alone would fix new
        // installations and leave his own desktop exactly as it was — and "the
        // windows have no shadow" is his report, not a new machine's.
        //
        // Measured before touching it: with the shadow switched off and on
        // again at the same window position, the wallpaper beside the window
        // differs by up to 192 (sum of R+G+B) and fades out over exactly 30 px.
        // The shadow was always being drawn. At 28/2/6 it was simply too small
        // and too pale to read as one.
        //
        // ⚠️ ONLY THE UNTOUCHED TRIPLE IS LIFTED. Somebody who set their own
        // numbers chose them, and a migration that overwrites a choice is a bug
        // with a version number on it.
        function (cfg) {
            var l = cfg.look
            if (l && typeof l === "object"
                && l.shadowSoftness === 28 && l.shadowSpread === 2
                && l.shadowOffsetY === 6) {
                l.shadowSoftness = 40
                l.shadowSpread = 3
                l.shadowOffsetY = 8
            }
            return cfg
        },

        // 7 → 8: a frozen copy of the DEFAULT key bindings is dropped.
        //
        // ⚠️ THIS IS A LANDMINE THAT WOULD HAVE GONE OFF ON EVERY FUTURE
        // BINDING. Found while adding one: `Mod+Tab` for the workspace map was
        // in the defaults, the generator ran, the config validated — and the
        // key was not in it. The reason was in shell.json: 63 entries under
        // `binds`, every one of them our own default, put there by the build in
        // which `keys.binds` was a `var` inside a nested JsonObject and carried
        // the whole list as its default. JsonAdapter wrote them out, the 5 → 6
        // step moved them to the top level, and "the file wins when it says
        // anything at all" did the rest: the defaults were frozen at the day
        // that file was first written. Every binding added since — and every one
        // that will ever be added — would have been invisible on every machine
        // that has run this shell, silently.
        //
        // So a list that is EXACTLY ours is not a decision, it is a fossil, and
        // it goes. The test is per entry: same key, same action, same argument.
        // One rebound key, one added binding, one entry we never shipped, and
        // the whole list is a decision and stays untouched.
        //
        // ⚠️ WHAT THIS DOES COST, said plainly: somebody who deleted a default
        // binding by hand and changed nothing else gets it back. That is the
        // one case this cannot tell from a fossil, and it is the smaller harm —
        // a binding you did not want is a nuisance, a binding you cannot get is
        // a feature that does not exist.
        function (cfg, ctx) {
            var b = cfg.binds
            var d = ctx ? ctx.defaultBinds : null
            if (!Array.isArray(b) || b.length === 0 || !Array.isArray(d))
                return cfg

            function sig(e) {
                return (e && e.action !== undefined ? e.action : "")
                     + " " + (e && e.arg !== undefined ? e.arg : "")
            }
            var ours = {}
            for (var i = 0; i < d.length; i++)
                if (d[i] && d[i].key !== undefined)
                    ours[d[i].key] = sig(d[i])

            for (var j = 0; j < b.length; j++) {
                var e = b[j]
                if (!e || e.key === undefined || ours[e.key] === undefined)
                    return cfg               // something we never shipped
                if (ours[e.key] !== sig(e))
                    return cfg               // a key bound to something else
            }
            delete cfg.binds
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
    //
    // ⚠️ `ctx` carries what a step cannot know on its own — today only
    // `defaultBinds`, for the 7 → 8 step. It is PASSED IN rather than imported:
    // Config already imports this file, so reaching back for Config from here
    // would close a circle between two singletons, and the failure mode for
    // that in this project is "Type Config unavailable" with a stack that names
    // the wrong file.
    function migrate(cfg, ctx) {
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
                out = step(out, ctx || {})
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
