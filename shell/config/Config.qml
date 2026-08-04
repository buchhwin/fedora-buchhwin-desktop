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
        onLoaded: root._failed = false
        onLoadFailed: root._failed = true

        JsonAdapter {
            id: adapter

            // Bumped only when a key is RENAMED or REMOVED, never when one is
            // added. 0 means "written before versioning existed".
            property int version: 1

            property JsonObject theme: JsonObject {
                property string palette: "everforest-dark"
                property string accent: "green"
                // "" = follow `palette`; a name here switches on a schedule later.
                property string lightPalette: "everforest-light"
            }

            property JsonObject look: JsonObject {
                property int rounding: 12          // every radius derives from this
                property int borderWidth: 0        // 0: no window borders anywhere
                property int gapsIn: 6
                property int gapsOut: 10
                property real opacityActive: 1.0
                property real opacityInactive: 0.96
                property real opacityPanel: 0.88   // translucency the blur sits behind
                property bool blur: true
                // The most expensive number in the whole desktop: every pass is
                // another full-screen GPU read on every frame. It gets a key of
                // its own rather than being buried in the generator, because it
                // is the first thing to turn down on a slow machine.
                property int blurPasses: 3
                property bool shadows: true
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
            }

            // Off by default: the notch IS the surface. That is a design
            // decision, not an oversight — so every function the bar would have
            // carried needs a key and an ipc verb as well, or it is unreachable.
            property JsonObject bar: JsonObject {
                property bool enabled: false
                property int height: 34
                property list<string> monitors: []
            }

            property JsonObject notch: JsonObject {
                property bool enabled: true
                property int flare: 14             // the concave shoulder radius
                property int collapsedWidth: 150
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
                    { key: "Mod+F",       action: "maximize-column",   desc: "Maximieren" },
                    { key: "Mod+Shift+F", action: "fullscreen-window", desc: "Vollbild" },
                    { key: "Mod+W",       action: "toggle-column-tabbed-display", desc: "Spalte als Reiter" },
                    { key: "Mod+O",       action: "toggle-overview",   desc: "Uebersicht" },
                    { key: "Mod+Shift+Slash", action: "show-hotkey-overlay", desc: "Tastenuebersicht" },

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
                    { key: "XF86MonBrightnessUp", action: "spawn-sh",
                      arg: "brightnessctl set 5%+", desc: "Heller", allowWhenLocked: true },
                    { key: "XF86MonBrightnessDown", action: "spawn-sh",
                      arg: "brightnessctl set 5%-", desc: "Dunkler", allowWhenLocked: true },

                    // --- session --------------------------------------------
                    { key: "Mod+Shift+E", action: "quit", desc: "Abmelden" },
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

            property JsonObject wallpaper: JsonObject {
                property string folder: ""     // set in M3.5; empty = none
                property string current: ""
                // "none" = wallpaper does not touch the palette (default),
                // "accent" = only the accent, "full" = surfaces and text too.
                property string derive: "none"
            }
        }
    }
}
