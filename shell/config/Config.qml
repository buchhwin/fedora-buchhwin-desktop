pragma Singleton

// The one place user settings live: ~/.config/buchhwin/shell.json.
//
// One file, one writer. The settings window writes through this adapter and
// nothing else touches the file, so there is no second format to keep in sync
// and no daemon in the middle. niri's own config.kdl is GENERATED from these
// values (see tools/niri.qml) — it is an output, never an input, and editing
// it by hand is editing something that will be overwritten.
//
// Every key has a default here. A missing file, a truncated file or a key that
// does not exist yet all resolve to the same working desktop, which is what
// makes it safe to ADD settings later without a migration for every one.
//
// `version` does not contradict that. Adding a key still needs no migration;
// RENAMING or REMOVING one does, because the old name is already sitting in
// somebody's file. See Migrations.qml — the chain is deliberately almost empty,
// and exists so that the first rename is not the moment we discover we need it.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property alias look: adapter.look
    readonly property alias theme: adapter.theme
    readonly property alias surfaces: adapter.surfaces
    readonly property alias notch: adapter.notch
    readonly property alias bar: adapter.bar
    readonly property alias dock: adapter.dock

    // Everything below feeds the generated niri config.
    readonly property alias programs: adapter.programs
    readonly property alias keys: adapter.keys
    readonly property alias input: adapter.input
    readonly property alias windows: adapter.windows
    readonly property alias outputs: adapter.outputs
    readonly property alias autostart: adapter.autostart
    readonly property alias workspaces: adapter.workspaces
    readonly property alias wallpaper: adapter.wallpaper
    readonly property alias location: adapter.location

    readonly property alias version: adapter.version

    // Resolve "@terminal" against `programs`, returning an ARGUMENT LIST.
    //
    // niri's `spawn` takes one string per argument: `spawn "kitty" "-e" "fish"`.
    // Passing the whole command line as a single string makes niri look for a
    // binary with spaces in its name, which fails with a message that does not
    // mention the real cause. So commands are lists everywhere, and only the
    // generator ever turns them into text.
    function program(ref) {
        if (typeof ref !== "string" || !ref.length)
            return []
        if (ref.charAt(0) !== "@")
            return [ref]
        var list = adapter.programs[ref.substring(1)]
        if (list === undefined || list === null)
            return []
        // JsonAdapter hands back a QJSValue wrapper, not a JS Array —
        // Array.isArray() says false for it. Length and indexing are what work.
        var out = []
        for (var i = 0; i < list.length; i++)
            out.push(String(list[i]))
        return out
    }

    readonly property bool loaded: file.loaded

    // "We know what the config is" — which includes knowing there isn't one.
    //
    // On a fresh machine there is no file, the adapter defaults ARE the right
    // answer, and waiting for a load that will never come would block until
    // timeout. `_failed` covers that.
    //
    // ⚠️ `settled` is NOT the same as "a one-shot read is safe". Measured:
    // `loaded` turns true one event-loop step BEFORE the JsonAdapter pushes the
    // parsed values into its properties, so reading Config.look.gapsOut in the
    // same tick still returns the default. A binding survives that (it
    // re-evaluates); a generator that reads inside a function does not, and
    // writes the default into a file with no error anywhere — gapsOut 24 in
    // shell.json, `gaps 10` in config.kdl.
    //
    // The one-step deferral therefore lives in common/WaitFor.qml, so that
    // every consumer gets it instead of each rediscovering it. (`adapterUpdated`
    // looks like the right signal and is not: it does not fire on load.)
    readonly property bool settled: file.loaded || _failed
    property bool _failed: false

    function save() { file.writeAdapter() }

    // Migration ran and could not finish. Empty while all is well; the settings
    // window will show it, because a config that refused to move forward is
    // something the user has to know about rather than something to log.
    property string migrationError: ""

    // Bring an older file forward, before anything reads meaning into it.
    //
    // ⚠️ This runs on the RAW TEXT, not through the adapter — JsonAdapter drops
    // every key it does not declare, so by the time the adapter has parsed the
    // file the old field a migration exists to rescue is already gone.
    //
    // The rewrite goes through the same FileView that read it. A second view on
    // this path would be the trap that has cost this project three debugging
    // rounds; and because `watchChanges` reloads afterwards, the adapter ends up
    // parsing the MIGRATED text rather than the original.
    function _migrate() {
        var raw = file.text()
        if (!raw || !raw.length)
            return                    // no file: the defaults are correct

        var cfg
        try {
            cfg = JSON.parse(raw)
        } catch (e) {
            // A file we cannot parse must not be "migrated" — that would mean
            // replacing it with guesswork. Leave it; FileView already shouted.
            root.migrationError = "shell.json is not valid JSON: " + e
            return
        }

        if (Migrations.fromFuture(cfg)) {
            root.migrationError =
                "shell.json was written by a newer build (version " +
                Migrations.versionOf(cfg) + " > " + Migrations.current +
                "); leaving it untouched"
            return
        }
        if (!Migrations.needed(cfg)) {
            root.migrationError = ""
            return
        }

        var res = Migrations.migrate(cfg)
        if (!res.ok) {
            root.migrationError = res.error
            return
        }
        root.migrationError = ""
        // Triggers onFileChanged → reload → onLoaded, where `needed` is now
        // false. One pass, then it settles.
        file.setText(JSON.stringify(res.config, null, 2) + "\n")
    }

    FileView {
        id: file
        path: Quickshell.env("XDG_CONFIG_HOME")
              ? Quickshell.env("XDG_CONFIG_HOME") + "/buchhwin/shell.json"
              : Quickshell.env("HOME") + "/.config/buchhwin/shell.json"
        watchChanges: true
        // Atomic: a settings write that is interrupted must not leave a
        // half-written file that the next start refuses to parse.
        atomicWrites: true
        onFileChanged: reload()
        // A parse failure must NOT overwrite the user's file with defaults.
        printErrors: true
        onLoaded: {
            root._failed = false
            root._migrate()
        }
        onLoadFailed: root._failed = true

        JsonAdapter {
            id: adapter

            // Bumped only when a key is RENAMED or REMOVED, never when one is
            // added. 0 means "written before versioning existed".
            property int version: 3

            property JsonObject theme: JsonObject {
                property string palette: "everforest-dark"
                property string accent: "green"
                // "" = follow `palette`; a name here switches on a schedule later.
                property string lightPalette: "everforest-light"
            }

            property JsonObject look: JsonObject {
                property int rounding: 16          // every radius derives from this
                property int borderWidth: 0        // 0: no window borders anywhere
                property int gapsIn: 8
                // Windows should read as separate objects lying on the
                // wallpaper, not as panes butted against the screen edge —
                // "bubbles", in the words of the brief. That is this number
                // plus `rounding` plus `shadows`, and it is the one of the
                // three you actually feel.
                property int gapsOut: 16
                property real opacityActive: 1.0
                property real opacityInactive: 0.98
                property real opacityPanel: 0.88   // translucency the blur sits behind
                // The terminal's own background, through kitty rather than
                // through the compositor — see tools/render.qml for why.
                //
                // ⚠️ This is the single biggest lever on the glass look, bigger
                // than any blur setting: blur is only visible where the window
                // is see-through, so at 0.90 there was nothing to see and every
                // blur pass behind it was paid for and wasted. Measured against
                // the reference screenshot, which is open enough to read the
                // wallpaper through the terminal while the text stays sharp —
                // that last part is why this lives in kitty's own
                // background_opacity and not in compositor opacity, which would
                // fade the glyphs out with it.
                property real opacityTerminal: 0.62
                property bool blur: true
                // The most expensive number in the whole desktop: every pass is
                // another full-screen GPU read on every frame. It gets a key of
                // its own rather than being buried in the generator, because it
                // is the first thing to turn down on a slow machine.
                property int blurPasses: 3
                // ⚠️ The FREE one, and therefore the one to reach for first.
                // niri's own words: "Larger values produce a smoother blur, at
                // no additional GPU cost", and "try increasing offset first
                // until you start getting artifacts. Then, if you still need
                // smoother blur, increase passes by 1." niri's default is 3.
                property real blurOffset: 5
                // Pixel noise over the blur. It exists to break up the colour
                // banding that a wide blur produces on a gradient — which is
                // exactly what a sunset wallpaper is. niri's default is 0.02.
                property real blurNoise: 0.03
                // Saturation of what shows through: 0 is grey, 1 is untouched,
                // 2 is doubled. This is the difference between glass and frosted
                // plastic — blur alone washes the colour out, and the reference
                // screenshots are anything but washed out. niri's default is 1.5.
                property real blurSaturation: 1.8
                property bool shadows: true
                // A shadow you notice as depth rather than as a shadow. These
                // are niri's own numbers (CSS box-shadow semantics): softness
                // is the blur radius, spread grows the rectangle, offset moves
                // it down. Generous and soft, as in the reference screenshots —
                // and the same three values apply to windows AND to our own
                // surfaces, so nothing floats differently from anything else.
                property int shadowSoftness: 28
                property int shadowSpread: 2
                property int shadowOffsetY: 6
                property string fontUi: "Inter"
                property string fontMono: "JetBrainsMono Nerd Font"
                // ⚠️ "Material Symbols Rounded" is NOT what Fedora ships.
                // material-icons-fonts provides the older "Material Icons Round";
                // fc-match resolves the Symbols name to Noto Sans, so every icon
                // silently renders as a fallback glyph or as tofu. Measured, not
                // assumed — the gear only appeared because U+2699 happens to
                // exist in Noto Sans.
                property string fontIcon: "Material Icons Round"
                property int fontSize: 11          // pt
                // full | minimal — minimal turns motion and effects off wholesale
                property string profile: "full"
            }

            // Every surface can be switched off on its own, and limited to
            // named monitors. An empty list means "all screens".
            property JsonObject surfaces: JsonObject {
                property bool notifications: true
                property bool osd: true
                property bool dock: false
                // The wallpaper is drawn by the shell rather than by a second
                // daemon, so it is a surface like any other and switches off
                // like any other — leaving whatever is behind it, which is the
                // compositor's own background.
                property bool wallpaper: true
            }

            // Off by default: the notch IS the surface. That is a design
            // decision, not an oversight — so every function the bar would have
            // carried needs a key and an ipc verb as well, or it is unreachable.
            property JsonObject bar: JsonObject {
                property bool enabled: false
                property int height: 34
                property list<string> monitors: []
            }

            // ⚠️ `collapsedWidth` is the width AT THE SCREEN EDGE — the widest
            // point of the shape, not the width of the pill's body. The
            // shoulders flare outwards towards the edge, so the body measures
            // `collapsedWidth - 2 * flare`. That is what keeps the layer surface
            // exactly as big as what is painted on it: niri blurs and shadows
            // the whole surface, invisible margins included, and a shape that
            // reached past its own window was the coloured halo around the pill.
            property JsonObject notch: JsonObject {
                property bool enabled: true
                property int flare: 7             // the concave shoulder radius
                property int collapsedWidth: 150
                // Its own key on purpose. This used to borrow `bar.height`,
                // which meant the notch changed size when a bar that was
                // switched off was resized.
                property int collapsedHeight: 34
                property int cornerRadius: 9      // the two rounded corners below
                property int expandedHeight: 135
                property int minExpandedWidth: 619
                property list<string> monitors: []
            }

            property JsonObject dock: JsonObject {
                property int iconSize: 40
                property list<string> pinned: []
                property list<string> monitors: []
            }

            // ---------------------------------------------------------------
            // Programs the key bindings point at.
            //
            // ARGUMENT LISTS, not command lines — see Config.program(). A key
            // refers to one of these as "@terminal", so changing your terminal
            // is one edit here instead of a hunt through the bindings.
            property JsonObject programs: JsonObject {
                property list<string> terminal: ["kitty"]
                property list<string> browser: ["brave-browser"]
                property list<string> fileManager: ["nautilus"]
                property list<string> editor: ["code"]
                property list<string> imageViewer: ["loupe"]
                property list<string> video: ["vlc"]
                // Deliberately empty until M6 builds one. An empty list means
                // the generator skips the binding entirely rather than writing
                // a key that silently does nothing.
                property list<string> launcher: []
            }

            // ---------------------------------------------------------------
            // Key bindings. Written to config.kdl, never handled by the shell:
            // niri has no protocol for shell-owned shortcuts, and keys that
            // live in the compositor keep working when the shell is dead.
            //
            // Each entry: { key, action, arg, desc } plus optional
            // allowWhenLocked / repeat / cooldownMs.
            //   action "spawn"     → arg is a program ref ("@terminal") or a
            //                        bare command name
            //   action "spawn-sh"  → arg is a shell line (pipes, $VARS)
            //   anything else      → a niri action, verbatim; arg is its
            //                        argument if it takes one
            property JsonObject keys: JsonObject {
                property string mod: "Super"

                property var binds: [
                    // --- programs -------------------------------------------
                    { key: "Mod+Return",       action: "spawn", arg: "@terminal",    desc: "Terminal" },
                    { key: "Mod+B",            action: "spawn", arg: "@browser",     desc: "Browser" },
                    { key: "Mod+E",            action: "spawn", arg: "@fileManager", desc: "Dateimanager" },
                    { key: "Mod+Shift+C",      action: "spawn", arg: "@editor",      desc: "Editor" },

                    // --- rescue: these must survive a dead shell -------------
                    { key: "Mod+Shift+Return", action: "spawn", arg: "@terminal",
                      desc: "Rettung: Terminal", allowWhenLocked: false },
                    { key: "Mod+Ctrl+Shift+R", action: "spawn-sh",
                      arg: "systemctl --user restart buchhwin-shell",
                      desc: "Rettung: Shell neu starten" },

                    // --- focus (niri convention: Mod moves focus) ------------
                    { key: "Mod+Left",  action: "focus-column-left",  desc: "Fokus nach links" },
                    { key: "Mod+Right", action: "focus-column-right", desc: "Fokus nach rechts" },
                    { key: "Mod+Up",    action: "focus-window-up",    desc: "Fokus nach oben" },
                    { key: "Mod+Down",  action: "focus-window-down",  desc: "Fokus nach unten" },
                    { key: "Mod+H",     action: "focus-column-left",  desc: "Fokus nach links" },
                    { key: "Mod+L",     action: "focus-column-right", desc: "Fokus nach rechts" },
                    { key: "Mod+K",     action: "focus-window-up",    desc: "Fokus nach oben" },
                    { key: "Mod+J",     action: "focus-window-down",  desc: "Fokus nach unten" },

                    // --- move -----------------------------------------------
                    { key: "Mod+Shift+Left",  action: "move-column-left",  desc: "Fenster nach links" },
                    { key: "Mod+Shift+Right", action: "move-column-right", desc: "Fenster nach rechts" },
                    { key: "Mod+Shift+Up",    action: "move-window-up",    desc: "Fenster nach oben" },
                    { key: "Mod+Shift+Down",  action: "move-window-down",  desc: "Fenster nach unten" },

                    // --- the four Hyprland groups niri has no equivalent for.
                    // Remapped to the nearest real meaning rather than dropped;
                    // docs/NIRI.md says plainly that these changed.
                    { key: "Mod+Ctrl+Left",  action: "set-column-width", arg: "-10%",
                      desc: "Spalte schmaler (war: Snap links)" },
                    { key: "Mod+Ctrl+Right", action: "set-column-width", arg: "+10%",
                      desc: "Spalte breiter (war: Snap rechts)" },
                    { key: "Mod+Ctrl+Up",    action: "maximize-column",
                      desc: "Spalte maximieren (war: Snap maximieren)" },
                    { key: "Mod+Ctrl+Down",  action: "switch-preset-column-width",
                      desc: "Breiten durchschalten (war: Snap wiederherstellen)" },
                    { key: "Mod+Shift+J",    action: "consume-or-expel-window-right",
                      desc: "Fenster in die Spalte holen (war: Split-Richtung)" },
                    { key: "Mod+Shift+K",    action: "consume-or-expel-window-left",
                      desc: "Fenster aus der Spalte schieben" },
                    { key: "Mod+P",          action: "toggle-window-floating",
                      desc: "Schwebend an/aus (war: Anpinnen)" },
                    { key: "Mod+odiaeresis", action: "focus-workspace", arg: "scratch",
                      desc: "Ablage (war: Scratchpad)" },
                    { key: "Mod+Shift+odiaeresis", action: "move-window-to-workspace", arg: "scratch",
                      desc: "Fenster in die Ablage" },

                    // --- windows --------------------------------------------
                    { key: "Mod+Q",       action: "close-window", desc: "Fenster schliessen", repeat: false },
                    { key: "Alt+F4",      action: "close-window", desc: "Fenster schliessen", repeat: false },
                    // Fullscreen is the one people reach for, so it gets the
                    // short key. `fullscreen-window` is already a toggle, so the
                    // same press brings the window back.
                    { key: "Mod+F",       action: "fullscreen-window", desc: "Vollbild" },
                    { key: "Mod+Shift+F", action: "maximize-column",   desc: "Maximieren" },
                    { key: "Mod+W",       action: "toggle-column-tabbed-display", desc: "Spalte als Reiter" },
                    { key: "Mod+O",       action: "toggle-overview",   desc: "Uebersicht" },
                    { key: "Mod+Shift+Slash", action: "show-hotkey-overlay", desc: "Tastenuebersicht" },

                    // --- the island ------------------------------------------
                    // Keys reach the shell through its ipc socket, which is
                    // also why they keep working when the shell is dead: they
                    // simply reach nobody, instead of the compositor eating
                    // them. ⚠️ `qs ipc call` takes no ARGUMENTS in 0.2.1, so
                    // each page is its own parameterless verb — see ipc/Ipc.qml.
                    //
                    // Every page has a key, without exception. The bar is OFF
                    // in the default setup, so a page reachable only by
                    // clicking the bar would not be reachable at all.
                    { key: "Mod+M", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch media",
                      desc: "Medien in der Insel" },
                    { key: "Mod+N", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch notifications",
                      desc: "Mitteilungen" },
                    { key: "Mod+comma", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch quick",
                      desc: "Schnelleinstellungen" },
                    { key: "Mod+C", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch calendar",
                      desc: "Kalender" },
                    { key: "Mod+T", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch tray",
                      desc: "Infobereich" },
                    { key: "Mod+Shift+N", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch event",
                      desc: "Neuer Termin" },
                    { key: "Mod+Shift+W", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch wallpaper",
                      desc: "Hintergrundbild waehlen" },
                    { key: "Mod+Escape", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch collapse",
                      desc: "Insel schliessen" },

                    // --- screenshots (niri does all three itself) ------------
                    { key: "Print",       action: "screenshot",        desc: "Screenshot: Auswahl" },
                    { key: "Mod+S",       action: "screenshot",        desc: "Screenshot: Auswahl" },
                    { key: "Mod+Shift+S", action: "screenshot-screen", desc: "Screenshot: ganzer Schirm" },
                    { key: "Mod+Ctrl+S",  action: "screenshot-window", desc: "Screenshot: Fenster" },

                    // --- hardware keys, must work on the lock screen ---------
                    { key: "XF86AudioRaiseVolume", action: "spawn-sh",
                      arg: "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+",
                      desc: "Lauter", allowWhenLocked: true },
                    { key: "XF86AudioLowerVolume", action: "spawn-sh",
                      arg: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
                      desc: "Leiser", allowWhenLocked: true },
                    { key: "XF86AudioMute", action: "spawn-sh",
                      arg: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
                      desc: "Ton aus", allowWhenLocked: true },
                    { key: "XF86AudioMicMute", action: "spawn-sh",
                      arg: "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
                      desc: "Mikrofon aus", allowWhenLocked: true },
                    // ⚠️ brightnessctl FIRST, the shell second, joined with `;`
                    // rather than `&&`. The screen has to brighten even when the
                    // shell is dead — that is the one moment when not being able
                    // to see the screen is worst — so telling the island is a
                    // best-effort afterthought, never a precondition.
                    { key: "XF86MonBrightnessUp", action: "spawn-sh",
                      arg: "brightnessctl set 5%+ ; qs -c buchhwin ipc call notch brightness",
                      desc: "Heller", allowWhenLocked: true },
                    { key: "XF86MonBrightnessDown", action: "spawn-sh",
                      arg: "brightnessctl set 5%- ; qs -c buchhwin ipc call notch brightness",
                      desc: "Dunkler", allowWhenLocked: true },

                    // --- session --------------------------------------------
                    // ⚠️ This was bound straight to niri's `quit`: one keystroke,
                    // no question, every unsaved thing gone. It opens the session
                    // page now, and THAT asks before anything irreversible.
                    { key: "Mod+Shift+E", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch session",
                      desc: "Sitzung beenden" },
                    // ⚠️ NOT Mod+L, however conventional that is: Mod+L is
                    // already focus-column-right in the vim group. A second
                    // binding for the same key is the kind of leftover the
                    // predecessor collected, and tests/niri-config.sh now fails
                    // on one.
                    { key: "Mod+Ctrl+L", action: "spawn-sh",
                      arg: "loginctl lock-session", desc: "Sperren" },
                    { key: "Mod+Shift+P", action: "power-off-monitors", desc: "Bildschirme aus" }
                ]
            }

            // ---------------------------------------------------------------
            property JsonObject input: JsonObject {
                property JsonObject keyboard: JsonObject {
                    property string layout: "de"
                    property string variant: ""
                    property string options: ""
                    property int repeatDelay: 400   // snappier than niri's 600
                    property int repeatRate: 40
                }
                // ⚠️ libinput flags do not accept `false` — `natural-scroll false`
                // is a hard parse error, unlike most other niri flags. The
                // generator must OMIT a false flag, never write it out.
                property JsonObject touchpad: JsonObject {
                    property bool tap: true
                    property bool dwt: true             // disable while typing
                    property bool naturalScroll: true
                    property bool middleEmulation: true
                    property real accelSpeed: 0.2
                    property string accelProfile: "adaptive"
                    property string scrollMethod: "two-finger"
                    property string clickMethod: "clickfinger"
                }
                property JsonObject mouse: JsonObject {
                    property bool naturalScroll: false
                    property real accelSpeed: 0.0
                    property string accelProfile: "flat"
                }
                property bool focusFollowsMouse: false
                property bool warpMouseToFocus: false
            }

            // ---------------------------------------------------------------
            property JsonObject windows: JsonObject {
                // No client-side decorations where a client will listen.
                property bool noCsd: true
                // Programs that must never be recorded or streamed.
                property list<string> blockFromScreencast: []
                // Windows that get the wallpaper blurred behind them.
                //
                // ⚠️ Blur is only VISIBLE where the window is translucent —
                // an opaque window covers it completely. The terminal is here
                // because look.opacityTerminal makes it see-through; adding an
                // opaque application would cost the GPU work and show nothing.
                //
                // niri turns on "xray" automatically alongside blur, which
                // blurs the wallpaper ONCE and reuses it for every window
                // instead of recomputing per window per frame. That is the
                // cheap path and the reason this is affordable on a laptop.
                property list<string> blurred: ["kitty"]
                // app-ids that should open floating.
                property list<string> floating: []
            }

            // Empty = let niri decide. Filled in per machine; the VM and the
            // laptop are not the same and this file is not shared between them.
            property var outputs: []

            // Extra programs for the session. NOT the shell and NOT the
            // clipboard watcher — those are systemd user units already, and
            // listing them here too would start a second copy of each.
            property list<string> autostart: []

            property list<string> workspaces: ["scratch"]

            // The wallpaper, and the one key that makes it colour the desktop.
            //
            // There is no separate "derive" switch: `theme.palette` set to
            // "wallpaper" IS the switch, and a second key that means the same
            // thing is how a settings file starts to contradict itself. It
            // existed until version 1 and is removed by a migration.
            // Where this machine is — for EVERYTHING that needs a place, not
            // for the weather alone. Today: the weather; next: sunrise and
            // sunset for automatic light/dark, and gammastep's night light.
            //
            // COORDINATES, not a search term. A name is ambiguous, would need
            // resolving on every start, and resolving needs the network — so a
            // laptop opened in a tunnel would show nothing for a place it has
            // known for months.
            //
            // ⚠️ No timezone here. The system knows it, and a copy drifts.
            property JsonObject location: JsonObject {
                property string name: ""      // for display only
                property real lat: NaN
                property real lon: NaN
                // ⚠️ No `source` field. A guess is never written here, so
                // anything in this block IS the answer you gave — the presence
                // of a name is the whole distinction. The guess is recomputed
                // from the timezone on every start, in memory, which also keeps
                // it current when the machine travels.
            }

            property JsonObject wallpaper: JsonObject {
                // Where the picker looks. Set by the installer; empty means
                // there is no wallpaper on this machine, not "the home folder".
                property string folder: ""
                // The image in use, as a file:// URL. THIS is what survives a
                // restart — the derived palette is a cache keyed on it.
                property string current: ""
                property list<string> monitors: []
            }
        }
    }
}
