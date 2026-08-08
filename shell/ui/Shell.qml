// The desktop: one set of surfaces per screen.
//
// Two rules that decide how this file is shaped, both from hard-won practice:
//
//  * Filter monitors in the DELEGATE, never in the model. A model that only
//    contains the screens a surface wants makes the surface's own identity
//    depend on which screens exist — plug in a monitor and everything below it
//    is recreated. Filtering in the delegate means one instance per screen,
//    which either draws or does not.
//
//  * `activeAsync`, not `active`. A configuration change should destroy the
//    window; briefly hiding something should keep the window and drop its
//    contents. Loading synchronously in a property change handler stalls the
//    compositor for as long as the component takes to build.

import QtQuick
import Quickshell
import "../config"
import "../theme"
import "../ipc"
import "../services" as Services
import "surface"
import "launcher"
import "wallpaper"
import "notif"
import "settings"
import "common"

Scope {
    id: root

    // ⚠️ THIS IS WHAT STARTS THE LOCATION SERVICE. QML builds a singleton on
    // FIRST ACCESS, so one that nothing references never runs — and without
    // this line the timezone guess only happened the first time the quick
    // panel was opened, which is exactly the moment you would rather it were
    // already done. Measured: the guess simply never happened. The project has
    // now paid for this lesson four times.
    //
    // ⚠️ AND THE WEATHER IS DELIBERATELY *NOT* STARTED HERE.
    //
    // Creating it at shell construction crashes quickshell. Not a guess — the
    // backtrace is inside `JsonAdapter::deserializeRec` → `QMetaProperty::write`
    // → `QObjectWrapper::wrap`, SIGSEGV, and it was isolated to this by adding
    // and removing this one term: without it, zero crashes across many
    // restarts; with it, a crash loop and then intermittent crashes even after
    // the obvious causes (a Connections on a half-built singleton, an
    // XMLHttpRequest during construction) were fixed. It is a race inside
    // Quickshell's adapter, not something this file can hold correctly.
    //
    // So Weather is created when the quick panel first opens, exactly as it was
    // before. The cost is one second before the first temperature appears. The
    // alternative is a desktop that segfaults, which is not a trade.
    // ⚠️ AND THE COUNTDOWN, WHICH I BROKE TODAY AND MEASURED WITHIN THE HOUR.
    //
    // The tick timer runs on `Countdown.running`, so the service has to exist
    // for a timer to count at all. Until today it existed by accident: the
    // collapsed notch read `Countdown.active` to decide whether to show the
    // countdown instead of the clock, and that reference built the singleton.
    // Then the notch went back to showing only the clock — correctly — and the
    // only remaining reference was inside a `&&` chain in the aside's loader,
    // where it is never evaluated unless the pointer is on the notch.
    //
    // Measured, not reasoned: a timer restored with twelve seconds left rang
    // never, the state file still said `rang: false`, and `notify-send` by hand
    // produced a toast a second later — so the notification path was fine and
    // the countdown had simply never started. A timer that only runs while you
    // are hovering the notch is worse than no timer.
    //
    // Two names, one line each, and a comment that is longer than both because
    // the failure is invisible and the fix looks like nothing.
    readonly property string startServices: Services.Location.timezone
    readonly property bool startCountdown: Services.Countdown.active

    // ⚠️ AND THE SAME TRAP WOULD HAVE SWALLOWED THE IDLE WATCHER WHOLE. It owns
    // four IdleMonitors and nothing else in the shell asks it anything — it has
    // no readout, no icon, no page. A singleton nobody references is never
    // built, so the screen would simply never have gone off, and the settings
    // page would have been a set of numbers that did nothing at all.
    //
    // That is the failure the countdown had, and it is worth one line here to
    // not have it twice.
    readonly property int startIdle: Services.Idle.screenOffAfter

    // ⚠️ AND THE THIRD ONE, for exactly the same reason. Restore has no readout,
    // no icon and no page either: it watches the window list and opens things
    // once at login. Unreferenced it would never be built, and "restore my
    // session" would be a switch in the settings window that did nothing —
    // which is the same fault as the countdown and the idle watcher, now three
    // times in one file. Anything that only acts on a timer needs a line here.
    readonly property bool startRestore: Services.Restore.settled

    // ⚠️ AND THE THEMING WATCHER IS STARTED LATE, FOR THE SAME REASON AS
    // WEATHER — but it must be started, because without it changing the palette
    // recolours the shell and nothing else. That was the state until today:
    // tools/render.qml's header claimed the running shell re-rendered on a
    // palette change, and nothing in shell/ ever launched it. Pick a wallpaper,
    // and GTK, Qt, kitty and niri kept the old colours until somebody typed
    // `bhctl theme apply` by hand.
    //
    // A Timer rather than a property reference: the service reads two dozen
    // JsonAdapter values, and doing that during shell construction is the shape
    // that segfaults quickshell. It also guards itself on `Config.settled`, so
    // this is the belt to that file's braces — the crash cost this project a
    // whole debugging round once, and one line of deferral is cheap insurance.
    Timer {
        running: true
        interval: Theme.durSlow
        onTriggered: root.themingStarted = Services.Theming.available
    }
    property bool themingStarted: false

    // Whether a surface belongs on this screen. An empty list means all of
    // them, which is the only sane default for a machine whose monitor names
    // nobody has typed in yet.
    function wants(monitors, screen) {
        if (!monitors || monitors.length === 0)
            return true
        for (var i = 0; i < monitors.length; i++)
            if (String(monitors[i]) === screen.name)
                return true
        return false
    }

    // ⚠️ THE SETTINGS WINDOW IS OUTSIDE `Variants`, AND THAT IS THE POINT OF IT
    // BEING A WINDOW. Everything below is a layer surface and therefore belongs
    // to one screen, so it is built once per screen and each copy decides
    // whether to draw. A window belongs to no screen: niri places it, you move
    // it, and one per monitor would mean three settings windows opening at once
    // on a docked laptop.
    //
    // Loaded on `Ipc.settingsOpen` the same way the launcher is, so closing it
    // destroys it — and the window's own `closed` signal turns the flag back
    // off when niri is what closed it.
    LazyLoader {
        activeAsync: Ipc.settingsOpen
        component: SettingsWindow {}
    }

    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: perScreen
            required property var modelData

            readonly property bool barHere:
                Config.bar.enabled && root.wants(Config.bar.monitors, modelData)

            readonly property bool notchHere:
                Config.notch.enabled && root.wants(Config.notch.monitors, modelData)

            readonly property bool launcherHere:
                Config.launcher.enabled
                && root.wants(Config.launcher.monitors, modelData)

            // No image, no surface — an empty black layer over the compositor's
            // own background is not a wallpaper, it is a bug that looks like one.
            readonly property bool wallpaperHere:
                Config.surfaces.wallpaper
                && String(Services.Wallpaper.current).length > 0
                && root.wants(Config.wallpaper.monitors, modelData)

            // Furthest back, under everything including the bar's own strut.
            // niri zooms the background layer along with the overview, which is
            // the correct behaviour rather than a side effect: the wallpaper
            // belongs to the workspace you are looking at.
            LazyLoader {
                activeAsync: perScreen.wallpaperHere
                component: WallpaperSurface { modelData: perScreen.modelData }
            }

            // ONE window carries both. They are one drawn silhouette, so two
            // windows would mean two shapes that overlap and hide each other —
            // which is exactly what happened before this was merged.
            LazyLoader {
                activeAsync: perScreen.barHere || perScreen.notchHere
                component: ShellSurface {
                    modelData: perScreen.modelData
                    barEnabled: perScreen.barHere
                    notchEnabled: perScreen.notchHere
                }
            }

            // The pages, floating under the notch. Its own window so that both
            // it and the notch are exactly the size of what they draw — niri
            // blurs and shadows the whole surface, invisible margins included.
            LazyLoader {
                activeAsync: perScreen.notchHere && Ipc.expanded
                component: OverlaySurface { modelData: perScreen.modelData }
            }

            // ⚠️ THE PILL BESIDE THE NOTCH IS GONE, and so is its surface. It
            // existed because the collapsed notch had room for one meaning and
            // that meaning was the time, so a running timer needed somewhere
            // else to live. It has somewhere else now: the notch grows when the
            // pointer is on it and shows the timer inside itself, along with
            // what is playing and the status pill — see notch/NotchWide.qml.
            //
            // That removes a window, a layer namespace and the awkwardness the
            // old file admitted to in its own header: moving the pointer onto
            // the pill ended the hover on the notch and took the pill away.

            // The hot corners. Two tiny surfaces, each with its own dwell.
            //
            // ⚠️ `hotCorners` defaults to "right" and NOT "both", because niri
            // already owns the top-left corner and has it switched on — its own
            // docs say so. Choosing "left" or "both" also switches niri's off;
            // that happens in tools/niri.qml, so the two can never both answer
            // the same corner.
            LazyLoader {
                activeAsync: Config.surfaces.hotCorners === "left"
                             || Config.surfaces.hotCorners === "both"
                component: HotCorner {
                    modelData: perScreen.modelData
                    corner: "left"
                    onTriggered: Ipc.toggle("workspaces")
                }
            }

            LazyLoader {
                activeAsync: Config.surfaces.hotCorners === "right"
                             || Config.surfaces.hotCorners === "both"
                // ⚠️ THE PANEL'S NOTIFICATION TAB, NOT the `notifications`
                // page — and the difference is 1.6 seconds. That page is in
                // Ipc's `autoClosing` list because it is a REPORT: it appears
                // when something arrives and takes itself away again. Measured
                // with the corner working: rest the pointer, the page opens,
                // and it is gone before you have read it. What he asked for is
                // a notification CENTRE, which is somewhere you look — so the
                // corner opens the panel on that tab, and it stays until you
                // close it.
                component: HotCorner {
                    modelData: perScreen.modelData
                    corner: "right"
                    onTriggered: Ipc.showQuick(Ipc.quickNotifications)
                }
            }

            // The four rounded screen corners. ⚠️ One LazyLoader each rather
            // than one surface with four corners drawn on it: niri blurs and
            // shadows the WHOLE surface, so a fullscreen one would put both
            // behind the entire display. Four r × r textures instead.
            //
            // A radius of 0 creates nothing at all — not a surface drawing
            // nothing, no surface.
            //
            // ⚠️ WRITTEN OUT, NOT A `Repeater`, AND THE FIRST ATTEMPT WAS THE
            // Repeater. It instantiates delegates into an ITEM, and this
            // delegate is a `Scope` — so it built nothing, said nothing, and
            // `niri msg -j layers` answered "0 corner surfaces" while the
            // journal stayed clean. The two hot corners above are written out
            // for the same reason.
            LazyLoader {
                activeAsync: Config.surfaces.screenCornerRadius > 0
                component: ScreenCorner {
                    modelData: perScreen.modelData
                    corner: "top-left"
                }
            }
            LazyLoader {
                activeAsync: Config.surfaces.screenCornerRadius > 0
                component: ScreenCorner {
                    modelData: perScreen.modelData
                    corner: "top-right"
                }
            }
            LazyLoader {
                activeAsync: Config.surfaces.screenCornerRadius > 0
                component: ScreenCorner {
                    modelData: perScreen.modelData
                    corner: "bottom-left"
                }
            }
            LazyLoader {
                activeAsync: Config.surfaces.screenCornerRadius > 0
                component: ScreenCorner {
                    modelData: perScreen.modelData
                    corner: "bottom-right"
                }
            }

            // Only while a page is open. A permanent fullscreen surface that
            // swallows clicks is the kind of bug nobody suspects.
            LazyLoader {
                activeAsync: perScreen.notchHere && Ipc.expanded
                component: ClickCatcher { modelData: perScreen.modelData }
            }

            // The launcher, in the middle of the screen. Its own surface and
            // NOT a notch page: it is the one thing the brief says may be open
            // without the notch stepping aside, so it cannot go through
            // `Ipc.page`.
            //
            // ⚠️ It does not need `notchHere`. A machine with the notch turned
            // off still has to be able to start a program — tying the launcher
            // to the notch would make one setting quietly disable the other.
            LazyLoader {
                activeAsync: perScreen.launcherHere && Ipc.launcher
                component: LauncherSurface { modelData: perScreen.modelData }
            }

            // Arriving messages, top-right, on their own surface. Not a page of
            // the notch — see notif/ToastSurface.qml for why that was wrong.
            //
            // ⚠️ THIS IS ALSO WHAT STARTS THE NOTIFICATION SERVER. QML builds a
            // singleton on first access, so a service nothing references never
            // runs, and a daemon that never registers answers notify-send with
            // "The name is not activatable" — which reads like a D-Bus fault
            // rather than "nothing asked for it". The reference used to sit in
            // ShellSurface, which meant the server only existed if the notch
            // did.
            LazyLoader {
                activeAsync: Config.surfaces.notifications
                             && root.wants(Config.notifications.monitors,
                                           perScreen.modelData)
                component: ToastSurface { modelData: perScreen.modelData }
            }

            // Space is reserved by its own window, so the visible surface can
            // be taller than the room it takes. In notch-only mode this is
            // simply not created — not hidden, not zero-height.
            LazyLoader {
                activeAsync: perScreen.barHere || perScreen.notchHere
                component: Strut {
                    modelData: perScreen.modelData
                    edge: "top"
                    // The COLLAPSED height, never the expanded one. Reserving
                    // the expanded size would push every window 135 px down and
                    // leave a permanent empty band under the notch.
                    //
                    // Whichever of the two is actually on screen: with the bar
                    // off, reserving the bar's height was reserving room for
                    // something that is not there.
                    reserve: Math.max(perScreen.notchHere
                                      ? Config.notch.collapsedHeight : 0,
                                      perScreen.barHere ? Config.bar.height : 0)
                }
            }
        }
    }
}
