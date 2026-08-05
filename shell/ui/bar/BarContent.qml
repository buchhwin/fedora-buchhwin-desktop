// The bar's contents: everything that lives on the strip, minus the window.
//
// Split out of the window because bar and island are ONE shape now — this is
// laid into the silhouette rather than owning a surface of its own. The middle
// is left free; that is where the island sits.
//
// Design rules from the brief, applied rather than restated:
//   * accent marks the active thing and nothing else
//   * separation by space and surface, never by lines
//   * two font sizes at most, weights 400/500/600 (see common/BarText)
//   * 4 px grid — every gap is a Theme.spaceN

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../config"
import "../../services" as Services
import "../common"

Item {
    id: root

    // The window this belongs to, for tray menus that need somewhere to open.
    property var hostWindow: null

    readonly property var focusedWs: Services.Compositor.focusedWorkspace

    readonly property var visibleWindows: {
        var out = []
        var ws = root.focusedWs
        if (!ws) return out
        var all = Services.Compositor.windows
        for (var i = 0; i < all.length; i++)
            if (all[i].workspace_id === ws.id)
                out.push(all[i])
        return out
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space2
        anchors.rightMargin: Theme.space2
        spacing: Theme.space3

        // ------------------------------------------------- workspaces
        RowLayout {
            spacing: Theme.space1

            Repeater {
                model: Services.Compositor.workspaces

                Pill {
                    id: wsPill
                    required property var modelData
                    interactive: true
                    active: modelData.is_focused

                    BarText {
                        text: wsPill.modelData.name ? wsPill.modelData.name
                                                    : wsPill.modelData.idx
                        color: wsPill.active ? Theme.accentFg
                             : wsPill.modelData.is_urgent ? Theme.warn
                             : Theme.fgDim
                    }

                    TapHandler {
                        onTapped: Services.Compositor.focusWorkspace(wsPill.modelData.idx)
                    }
                }
            }
        }

        // ---------------------------------------------- open windows
        RowLayout {
            spacing: Theme.space1

            Repeater {
                model: root.visibleWindows

                Pill {
                    id: winPill
                    required property var modelData
                    interactive: true
                    active: modelData.is_focused

                    // Drawn, not written.
                    //
                    // The sketch asks for ▣ — a small filled box. Doing that
                    // with an icon font means depending on a glyph NAME
                    // existing in whichever icon set is installed, and when
                    // it does not the ligature text still takes up width:
                    // the first attempt produced a wide empty pill, because
                    // "square" is a Material SYMBOLS name and Fedora ships
                    // the older Material ICONS. A rectangle cannot fail that
                    // way, and it still takes its colour and radius from the
                    // token layer like everything else.
                    Rectangle {
                        width: Theme.space2
                        height: Theme.space2
                        radius: Theme.radiusXs
                        color: winPill.active ? Theme.accentFg : "transparent"  // literal-ok: absence of colour
                        border.width: winPill.active ? 0 : 1
                        border.color: Theme.fgDim

                        Behavior on color {
                            enabled: Theme.animate
                            ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                        }
                    }

                    TapHandler {
                        onTapped: Services.Compositor.focusWindow(winPill.modelData.id)
                    }
                }
            }
        }

        // The island sits here. Empty on purpose — the silhouette draws
        // through this gap, so nothing may be placed in it.
        Item { Layout.fillWidth: true }

        // Media, left of the status group as in the reference screenshot.
        MediaPill {}

        // A failed reload leaves the PREVIOUS config running, which from
        // the outside looks like "my change did nothing". Say which it was.
        Pill {
            visible: Services.Compositor.configFailed
            BarText {
                text: "broken config"
                color: Theme.error
            }
        }

        // No compositor is a state worth one sentence of text, not an
        // empty strip that reads as broken.
        BarText {
            visible: !Services.Compositor.available
            text: "no compositor"
            color: Theme.error
        }

        // ------------------------------------------------------- tray
        RowLayout {
            spacing: Theme.space1
            // Through the service, like everything else. Reaching into
            // Quickshell.Services.SystemTray from here meant no `available` and
            // no guard: for the first moments of a session the tray host has
            // not registered, `items.values` does not exist yet, and reading it
            // throws inside a binding — which takes the whole bar down rather
            // than showing an empty tray.
            visible: Services.Tray.available

            Repeater {
                model: Services.Tray.items

                Pill {
                    id: trayPill
                    required property var modelData
                    interactive: true

                    Image {
                        source: trayPill.modelData.icon
                        sourceSize.width: Theme.fontSizeLg
                        sourceSize.height: Theme.fontSizeLg
                        width: Theme.fontSizeLg
                        height: Theme.fontSizeLg
                        asynchronous: true
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onTapped: function (point, button) {
                            if (button === Qt.RightButton)
                                Services.Tray.menu(trayPill.modelData,
                                                   root.hostWindow, 0, root.height)
                            else
                                Services.Tray.activate(trayPill.modelData)
                        }
                    }
                }
            }
        }

        // ----------------------------------------------------- status
        // Each of these draws only where the hardware exists. On the test
        // VM Pipewire reports zero nodes and UPower zero devices, so both
        // stay hidden — which is the correct answer, not a missing feature.
        Pill {
            visible: Services.Audio.available
            interactive: true

            Icon {
                text: Services.Audio.muted ? "volume_off"
                    : Services.Audio.volume > 0.5 ? "volume_up" : "volume_down"
                size: Theme.fontSizeLg
                color: Services.Audio.muted ? Theme.fgDim : Theme.fg
            }

            TapHandler { onTapped: Services.Audio.toggleMute() }
        }

        Pill {
            visible: Services.Power.available

            RowLayout {
                spacing: Theme.space1

                Icon {
                    text: Services.Power.charging ? "battery_charging_full" : "battery_full"
                    size: Theme.fontSizeLg
                    // Accent is for the active thing; a low battery is a
                    // warning and gets the warning colour, not the accent.
                    color: Services.Power.critical ? Theme.error
                         : Services.Power.low ? Theme.warn
                         : Theme.fg
                }

                BarText {
                    text: Math.round(Services.Power.percent) + "%"
                }
            }
        }

        // ------------------------------------------------------ clock
        Pill {
            BarText {
                // SystemClock rather than a Timer: it ticks on the minute
                // boundary instead of a second after whenever the shell
                // happened to start, and it sleeps in between.
                text: {
                    function p(n) { return n < 10 ? "0" + n : "" + n }
                    return p(wallClock.hours) + ":" + p(wallClock.minutes)
                }
            }

            SystemClock {
                id: wallClock
                precision: SystemClock.Minutes
            }
        }

        // --------------------------------------------------- settings
        Pill {
            interactive: true
            Icon { text: "settings"; size: Theme.fontSizeLg }
            // The settings window is M8. Until then this is deliberately
            // inert rather than wired to something that does not exist.
        }
    }
}
