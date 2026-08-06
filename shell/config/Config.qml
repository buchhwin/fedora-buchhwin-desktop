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
    readonly property alias theming: adapter.theming
    readonly property alias surfaces: adapter.surfaces
    readonly property alias notifications: adapter.notifications
    readonly property alias clipboard: adapter.clipboard
    readonly property alias notch: adapter.notch
    readonly property alias bar: adapter.bar
    readonly property alias launcher: adapter.launcher

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
        file.setText(JSON.stringify(res.config, null, 2) + "\n")

        // ⚠️ THE NEW NUMBER IS ADOPTED HERE, NOT WHEN THE FILE COMES BACK.
        //
        // The write triggers onFileChanged → reload → onLoaded, and until that
        // round trip completes the adapter still reports the OLD version — so
        // anything asking "is this config current" during the first run after a
        // version bump gets the wrong answer. Measured: bumping to 5 made
        // tests/smoke.sh fail on its first run on the test VM and pass on the
        // second.
        //
        // Waiting for that notification is the same mistake theme/Scheme.qml
        // documents at length: in a container it never arrives at all. The
        // migration has already happened in memory, so the number is set from
        // memory and the file is what the NEXT start reads.
        //
        // Only the version needs this. JsonAdapter drops every key it does not
        // declare, so a removed key was never in the adapter to begin with.
        adapter.version = Migrations.current
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
            //
            // ⚠️ This number and Migrations.current must match, and NOTHING
            // ELSE may state it. The installer used to seed `"version": 2` and
            // `bhctl shell reset` used to write `"version": 1` while the code
            // said 3 — three places claiming to know, two of them wrong, and
            // only the migration chain quietly papering over it. Both now write
            // no version at all: a file without one reads as 0 and is migrated
            // forward, which is exactly the path a genuinely old file takes.
            property int version: 5

            property JsonObject theme: JsonObject {
                property string palette: "everforest-dark"
                property string accent: "green"
                // "" = follow `palette`; a name here switches on a schedule later.
                property string lightPalette: "everforest-light"
                // Used when `palette` is "custom": one colour, and the whole
                // 26-name scheme is calculated from it. The same calculation
                // the wallpaper goes through — the image only ever contributed
                // a hue and a saturation, so handing those over directly needs
                // no second generator. See theme/FromImage.qml.
                // The default seed a "custom" scheme is calculated from — not a
                // colour anything is painted with, and only in effect once the
                // user has chosen "custom", by which point it is their value.
                property string customColor: "#7fbbb3"  // literal-ok: a seed, not a style
            }

            // ⚠️ WHICH PROGRAMS WE COLOUR, AND HOW — one of three states each.
            //
            //   "colour"   the system's colours (wallpaper, custom, or a
            //              shipped palette — whatever `theme.palette` says)
            //   "neutral"  a grey scheme: themed, but colourless
            //   "off"      we write nothing AND remove what we wrote before,
            //              so the program looks the way it would without us
            //   "inherit"  follow `mode` below — the default, so switching
            //              everything at once is one edit rather than twelve
            //
            // ⚠️ "off" has to CLEAN UP, not merely skip. A switch that leaves
            // the last file lying there does nothing visible, and a setting
            // that does nothing is the fault this project has now fixed four
            // times over. Only our own files are touched: kitty.conf,
            // btop.conf and .gitconfig belong to the user and are never
            // overwritten — only the pointer line we added is taken back out.
            property JsonObject theming: JsonObject {
                property bool enabled: true
                property string mode: "colour"
                // ⚠️ FLAT, not `targets: { gtk: … }`. Two levels of JsonObject
                // nesting does not come back from the file — measured: the
                // block parsed, the inner values stayed at their defaults, and
                // every switch silently did nothing. Every other block in this
                // file is one level deep, and now so is this one.
                property string gtk: "inherit"
                property string qt: "inherit"
                property string kitty: "inherit"
                property string alacritty: "inherit"
                property string niri: "inherit"
                property string btop: "inherit"
                property string bat: "inherit"
                property string fastfetch: "inherit"
                property string delta: "inherit"
                property string tmux: "inherit"
                property string starship: "inherit"
                property string lazygit: "inherit"
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
                // Translucency the blur sits behind. Lower than it looks like it
                // should be: a panel is read, not looked through, so this is the
                // one place where legibility outranks the effect — but at 0.88
                // the blur behind it was being computed and then covered, the
                // same waste as the terminal at 0.90.
                property real opacityPanel: 0.78
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
                // The lit edge on our own surfaces — rim and sheen, no shader.
                // See the glass tokens in theme/Theme.qml for why it is drawn
                // this way and not as refraction.
                property bool glass: true
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
                // The wallpaper is drawn by the shell rather than by a second
                // daemon, so it is a surface like any other and switches off
                // like any other — leaving whatever is behind it, which is the
                // compositor's own background.
                property bool wallpaper: true
            }

            // How arriving notifications behave on screen. They are their own
            // surface in the top-right corner, NOT a page of the notch: the
            // notch is where you go to look at something, and a message that
            // arrives on its own has not been asked for. Making it take over
            // the notch meant every notification interrupted whatever the notch
            // was showing and then vanished after 1.6 s, whether it had been
            // read or not.
            property JsonObject notifications: JsonObject {
                // How long an ordinary toast stays. Senders may ask for their
                // own duration via `expireTimeout`, and that is honoured; this
                // is the answer when they do not.
                property int timeoutMs: 5000
                // ⚠️ Critical notifications never time out on their own. That
                // is the whole meaning of the urgency level, and a disk-full
                // warning that disappears while you are in another window is
                // worse than none.
                property int maxVisible: 3
                // ⚠️ Empty means every screen — which on two monitors means the
                // same message twice, once in each top-right corner. That is
                // the honest default (a message must not land on a screen you
                // are not looking at) but it is worth naming one output here
                // once a second monitor is in play.
                property list<string> monitors: []
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

            // The launcher, which is the one surface that opens in the MIDDLE
            // of the screen rather than at the notch — so the notch stays where
            // it is while it is open.
            //
            // A fixed size, unlike the notch pages: those are as big as their
            // content because their content is short, and a program list is
            // not. A launcher that changes shape while you type is a moving
            // target.
            property JsonObject launcher: JsonObject {
                property bool enabled: true
                property int width: 720
                property int height: 460
                property list<string> monitors: []
            }

            // The clipboard history page. Counts belong here rather than in the
            // page: a token decides what a row LOOKS like, a setting decides
            // how many of them you want to see. Anything that is a matter of
            // taste gets a key — see the plan's second promise, "alles  english-ok: quoted brief
            // einstellbar, und zwar aus demselben Satz".  // english-ok: his own words, quoted
            property JsonObject clipboard: JsonObject {
                // How tall the page opens, in rows. Six fits a laptop screen
                // without the island covering half of it.
                property int visibleRows: 6
            }

            // ⚠️ NO `dock` BLOCK. There was one — iconSize, pinned, monitors —
            // and nothing in the shell ever read a single key of it, because
            // the dock is M7 and has not been built. A setting that does
            // nothing is worse than a missing one: it is a promise, and the
            // only way to find out it was empty is to try it.
            //
            // It comes back with the dock, and then it will mean something.
            // Same for `surfaces.dock`, removed with it.

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
                // ⚠️ NO `launcher` KEY. There was one, empty, waiting for M6 to
                // fill it with the name of some other program. M6 built the
                // launcher instead, so the key would now point at a second one
                // that nothing starts — and a setting nothing reads is the
                // fault this project has removed four times. The launcher is
                // opened by `ipc call launcher toggle`, like every other
                // surface the shell owns.
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
                    { key: "Mod+E",            action: "spawn", arg: "@fileManager", desc: "File manager" },
                    { key: "Mod+Shift+C",      action: "spawn", arg: "@editor",      desc: "Editor" },

                    // --- rescue: these must survive a dead shell -------------
                    { key: "Mod+Shift+Return", action: "spawn", arg: "@terminal",
                      desc: "Rescue: terminal", allowWhenLocked: false },
                    { key: "Mod+Ctrl+Shift+R", action: "spawn-sh",
                      arg: "systemctl --user restart buchhwin-shell",
                      desc: "Rescue: restart the shell" },

                    // --- focus (niri convention: Mod moves focus) ------------
                    { key: "Mod+Left",  action: "focus-column-left",  desc: "Focus left" },
                    { key: "Mod+Right", action: "focus-column-right", desc: "Focus right" },
                    { key: "Mod+Up",    action: "focus-window-up",    desc: "Focus up" },
                    { key: "Mod+Down",  action: "focus-window-down",  desc: "Focus down" },
                    { key: "Mod+H",     action: "focus-column-left",  desc: "Focus left" },
                    { key: "Mod+L",     action: "focus-column-right", desc: "Focus right" },
                    { key: "Mod+K",     action: "focus-window-up",    desc: "Focus up" },
                    { key: "Mod+J",     action: "focus-window-down",  desc: "Focus down" },

                    // --- move -----------------------------------------------
                    { key: "Mod+Shift+Left",  action: "move-column-left",  desc: "Move window left" },
                    { key: "Mod+Shift+Right", action: "move-column-right", desc: "Move window right" },
                    { key: "Mod+Shift+Up",    action: "move-window-up",    desc: "Move window up" },
                    { key: "Mod+Shift+Down",  action: "move-window-down",  desc: "Move window down" },

                    // --- the four Hyprland groups niri has no equivalent for.
                    // Remapped to the nearest real meaning rather than dropped;
                    // docs/NIRI.md says plainly that these changed.
                    { key: "Mod+Ctrl+Left",  action: "set-column-width", arg: "-10%",
                      desc: "Narrower column (was: snap left)" },
                    { key: "Mod+Ctrl+Right", action: "set-column-width", arg: "+10%",
                      desc: "Wider column (was: snap right)" },
                    { key: "Mod+Ctrl+Up",    action: "maximize-column",
                      desc: "Maximise column (was: snap maximise)" },
                    { key: "Mod+Ctrl+Down",  action: "switch-preset-column-width",
                      desc: "Cycle preset widths (was: snap restore)" },
                    { key: "Mod+Shift+J",    action: "consume-or-expel-window-right",
                      desc: "Pull window into the column (was: split direction)" },
                    { key: "Mod+Shift+K",    action: "consume-or-expel-window-left",
                      desc: "Push window out of the column" },
                    { key: "Mod+P",          action: "toggle-window-floating",
                      desc: "Floating on/off (was: pin)" },
                    { key: "Mod+odiaeresis", action: "focus-workspace", arg: "scratch",
                      desc: "Scratch workspace" },
                    { key: "Mod+Shift+odiaeresis", action: "move-window-to-workspace", arg: "scratch",
                      desc: "Move window to the scratch workspace" },

                    // --- windows --------------------------------------------
                    { key: "Mod+Q",       action: "close-window", desc: "Close window", repeat: false },
                    { key: "Alt+F4",      action: "close-window", desc: "Close window", repeat: false },
                    // Fullscreen is the one people reach for, so it gets the
                    // short key. `fullscreen-window` is already a toggle, so the
                    // same press brings the window back.
                    { key: "Mod+F",       action: "fullscreen-window", desc: "Fullscreen" },
                    { key: "Mod+Shift+F", action: "maximize-column",   desc: "Maximise column" },
                    { key: "Mod+W",       action: "toggle-column-tabbed-display", desc: "Column as tabs" },
                    { key: "Mod+O",       action: "toggle-overview",   desc: "Overview" },
                    { key: "Mod+Shift+Slash", action: "show-hotkey-overlay", desc: "Keyboard shortcuts" },

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
                      desc: "Media in the island" },
                    { key: "Mod+N", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch notifications",
                      desc: "Notifications" },
                    { key: "Mod+comma", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch quick",
                      desc: "Quick settings" },
                    { key: "Mod+C", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch calendar",
                      desc: "Calendar" },
                    // ⚠️ TWO KEYS FOR ONE SURFACE, on purpose. Mod+D is what
                    // niri's own default config binds a launcher to, so it is
                    // the key somebody coming from any other setup will press
                    // first; Mod+Space is the one somebody coming from a Mac
                    // will press. Neither is used for anything else here, and a
                    // launcher nobody can find is a launcher nobody uses.
                    //
                    // `ipc call launcher`, not `notch`: it is not a notch page
                    // — it opens in the middle of the screen and leaves the
                    // notch alone. See ipc/Ipc.qml.
                    { key: "Mod+D", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call launcher toggle",
                      desc: "Launcher" },
                    { key: "Mod+Space", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call launcher toggle",
                      desc: "Launcher" },
                    { key: "Mod+T", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch tray",
                      desc: "Tray" },
                    // ⚠️ Mod+V, NOT Ctrl+V. Copy and paste belong to the
                    // application you are in — Ctrl+C and Ctrl+V go straight to
                    // it through the Wayland clipboard, and binding either of
                    // them here would take them away from every program on the
                    // machine. This opens the HISTORY; picking an entry puts it
                    // on the clipboard and you paste it as you always would.
                    { key: "Mod+V", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch clipboard",
                      desc: "Clipboard history" },
                    { key: "Mod+Shift+N", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch event",
                      desc: "New event" },
                    { key: "Mod+Shift+W", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch wallpaper",
                      desc: "Choose a wallpaper" },
                    // The same view the gear on the bar opens. It gets a key
                    // of its own because the bar is off by default, so without
                    // one the network and bluetooth controls would sit behind a
                    // surface most people never switch on.
                    { key: "Mod+Shift+comma", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch settings",
                      desc: "Network, bluetooth, sound and brightness" },
                    { key: "Mod+Escape", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch collapse",
                      desc: "Close the island" },

                    // ⚠️ Its own target, not a notch page: the bar is a
                    // surface, not something the island shows. Off by default
                    // and this is how it is tried out.
                    { key: "Mod+Shift+B", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call bar toggle",
                      desc: "Top bar on or off" },

                    // --- screenshots (niri does all three itself) ------------
                    { key: "Print",       action: "screenshot",        desc: "Screenshot: selection" },
                    { key: "Mod+S",       action: "screenshot",        desc: "Screenshot: selection" },
                    { key: "Mod+Shift+S", action: "screenshot-screen", desc: "Screenshot: whole screen" },
                    { key: "Mod+Ctrl+S",  action: "screenshot-window", desc: "Screenshot: window" },

                    // --- hardware keys, must work on the lock screen ---------
                    { key: "XF86AudioRaiseVolume", action: "spawn-sh",
                      arg: "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+",
                      desc: "Volume up", allowWhenLocked: true },
                    { key: "XF86AudioLowerVolume", action: "spawn-sh",
                      arg: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
                      desc: "Volume down", allowWhenLocked: true },
                    { key: "XF86AudioMute", action: "spawn-sh",
                      arg: "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
                      desc: "Mute", allowWhenLocked: true },
                    { key: "XF86AudioMicMute", action: "spawn-sh",
                      arg: "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
                      desc: "Mute the microphone", allowWhenLocked: true },
                    // ⚠️ brightnessctl FIRST, the shell second, joined with `;`
                    // rather than `&&`. The screen has to brighten even when the
                    // shell is dead — that is the one moment when not being able
                    // to see the screen is worst — so telling the island is a
                    // best-effort afterthought, never a precondition.
                    { key: "XF86MonBrightnessUp", action: "spawn-sh",
                      arg: "brightnessctl set 5%+ ; qs -c buchhwin ipc call notch brightness",
                      desc: "Brighter", allowWhenLocked: true },
                    { key: "XF86MonBrightnessDown", action: "spawn-sh",
                      arg: "brightnessctl set 5%- ; qs -c buchhwin ipc call notch brightness",
                      desc: "Dimmer", allowWhenLocked: true },

                    // --- session --------------------------------------------
                    // ⚠️ This was bound straight to niri's `quit`: one keystroke,
                    // no question, every unsaved thing gone. It opens the session
                    // page now, and THAT asks before anything irreversible.
                    { key: "Mod+Shift+E", action: "spawn-sh",
                      arg: "qs -c buchhwin ipc call notch session",
                      desc: "Session menu" },
                    // ⚠️ NOT Mod+L, however conventional that is: Mod+L is
                    // already focus-column-right in the vim group. A second
                    // binding for the same key is the kind of leftover the
                    // predecessor collected, and tests/niri-config.sh now fails
                    // on one.
                    // ⚠️ Starts the locker DIRECTLY rather than asking logind
                    // to. `loginctl lock-session` only emits a signal, and
                    // nothing in this desktop was listening — so this key did
                    // nothing at all, silently, which on a work machine is the
                    // worst way for a lock to fail.
                    //
                    // Spawning it from the keybinding also means locking still
                    // works when the shell is dead, which is the stated reason
                    // keys live in KDL rather than in the shell.
                    //
                    // ⚠️ `-c buchhwin`, not a path: quickshell treats the
                    // folder of the file it is given as the config root, so
                    // starting it by path would put theme/ and config/ outside
                    // that root and the singletons would never register.
                    { key: "Mod+Ctrl+L", action: "spawn-sh",
                      arg: "BUCHHWIN_MODE=lock qs -c buchhwin", desc: "Lock" },
                    { key: "Mod+Shift+P", action: "power-off-monitors", desc: "Screens off" }
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
