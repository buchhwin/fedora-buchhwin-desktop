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
import "../ipc"
import "../services" as Services
import "surface"
import "wallpaper"
import "common"

Scope {
    id: root

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

    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: perScreen
            required property var modelData

            readonly property bool barHere:
                Config.bar.enabled && root.wants(Config.bar.monitors, modelData)

            readonly property bool notchHere:
                Config.notch.enabled && root.wants(Config.notch.monitors, modelData)

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

            // Only while the island is open. A permanent fullscreen surface
            // that swallows clicks is the kind of bug nobody suspects.
            LazyLoader {
                activeAsync: perScreen.notchHere && Ipc.expanded
                component: ClickCatcher { modelData: perScreen.modelData }
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
                    reserve: Config.bar.height
                }
            }
        }
    }
}
