// The notch with the pointer on it: what is playing, what time it is, and how
// the machine is doing.
//
// Straight from the reference screenshot
// (shots/2026-08-06/vorlage-notch-ausgefahren.png): a square of album art with
// the title and artist beside it on the LEFT, the time large with the date
// small under it in the MIDDLE, and a rounded pill on the RIGHT holding the
// network and battery icons in the accent colour.
//
// ⚠️ ONLY THE PILL OPENS ANYTHING. Clicking the notch itself used to open the
// quick panel and no longer does — "und **nur diese Pille** öffnet das             english-ok: quoted brief
// Quick-Panel, der Klick auf die Notch nichts mehr". That is why the pill is a   english-ok: quoted brief
// Pill (which brings its own tap target sized to the whole shape) and why the
// island's own TapHandler stands down.
//
// ⚠️ NOTHING EMPTY IS DRAWN. No player means no artwork and no title, not a
// placeholder; no timer means no timer; a machine with no battery shows no
// battery. The shape is sized from what survives that, so a quiet desktop gets
// a smaller notch rather than a wide one full of nothing.
//
// ⚠️ AND THE ARTWORK IS LOADED AT THE SIZE IT IS DRAWN. `sourceSize` on a cover
// that arrives as a 1400 px JPEG is the difference between one thumbnail and a
// full-resolution decode every time a track changes.

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../config"
import "../../ipc"
import "../../services" as Services
import "../common"
import "../../common"

Item {
    id: root

    // The clock is handed in rather than read again: NotchContent already has
    // one SystemClock, and two of them on one screen can disagree by a minute
    // at the wrong moment.
    //
    // ⚠️ THE WHOLE DATE, not the hour and the minute. It used to be two ints,
    // and the date line underneath had to fake a dependency on `minutes` to be
    // rebuilt at all — a `new Date()` with nothing to depend on is evaluated
    // once and then shows yesterday until the shell restarts. One Date is the
    // dependency, so the trick is gone with the thing that needed it.
    property var now: null

    // ⚠️ ANCHORS, NOT A ROW LAYOUT, and it is the clock that decides it. In a
    // row the middle column sits wherever the two beside it leave room — so with
    // nothing playing the clock drifted off centre (measured: shape centre 960,
    // clock centre 930), and it would move again the moment a track started.
    // The reference has the time in the MIDDLE of the shape, full stop.
    //
    // So the three groups are anchored — left, centre, right — and the width is
    // computed to keep the centre actually central: whichever side is wider sets
    // the margin on BOTH sides. That is what makes the clock hold still while
    // music starts and stops.
    readonly property real sideWidth: Math.max(media.implicitWidth,
                                               right.implicitWidth)
    implicitWidth: root.sideWidth * 2 + centre.implicitWidth + Theme.space5 * 2
    implicitHeight: Math.max(media.implicitHeight, centre.implicitHeight,
                             right.implicitHeight)

    // ------------------------------------------------------------------ media
    RowLayout {
        id: media
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: Services.Media.available
               && (Config.media ? Config.media.showInIsland : true)
        spacing: Theme.space3

        Rectangle {
            implicitWidth: Theme.space6 * 2
            implicitHeight: Theme.space6 * 2
            radius: Theme.radiusSm
            color: Theme.surface
            clip: true

            Image {
                anchors.fill: parent
                source: Services.Media.artUrl
                sourceSize.width: parent.width
                sourceSize.height: parent.height
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: Services.Media.artUrl.length > 0
            }

            Icon {
                anchors.centerIn: parent
                visible: Services.Media.artUrl.length === 0
                text: "music_note"
                size: Theme.fontSizeLg
                color: Theme.fgDim
            }
        }

        ColumnLayout {
            spacing: 0   // literal-ok: absence of a gap — title and artist are
                         // one label on two lines, not two things
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                spacing: Theme.space1
                Icon {
                    text: "graphic_eq"
                    size: Theme.fontSizeSm
                    color: Theme.accent
                    visible: Services.Media.playing
                }
                BarText {
                    text: Services.Media.title
                    font.pixelSize: Theme.fontSize
                    font.weight: Theme.weightSemibold
                    elide: Text.ElideRight
                    Layout.maximumWidth: Theme.space6 * 5
                }
            }

            BarText {
                text: Services.Media.artist
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                elide: Text.ElideRight
                visible: text.length > 0
                Layout.maximumWidth: Theme.space6 * 5
            }
        }
    }

    // ------------------------------------------------------------ clock, date
    ColumnLayout {
        id: centre
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0   // literal-ok: absence of a gap — the time and its date are
                     // one label on two lines

        BarText {
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Theme.fontSizeXl
            font.weight: Theme.weightSemibold
            color: Theme.fg
            text: Clock.time(root.now)
        }

        BarText {
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
            // The SHORT form: this is a pill, not a screen. The lock screen's
            // long form is a separate setting for that reason.
            text: Clock.dateShort(root.now)
        }
    }

    // --------------------------------------------------------- timer + pill
    RowLayout {
        id: right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space3

        // Only while one is running or has just rung. This is what the separate
        // pill beside the notch used to be — it lives in here now, so a hover
        // shows everything at once instead of two surfaces appearing side by
        // side.
        RowLayout {
            visible: Services.Countdown.active || Services.Countdown.rang
            spacing: Theme.space1
            Layout.alignment: Qt.AlignVCenter

            Icon {
                text: "timer"
                size: Theme.fontSize
                color: Services.Countdown.rang ? Theme.warn : Theme.fgMuted
            }
            BarText {
                text: Services.Countdown.label
                font.pixelSize: Theme.fontSize
                color: Services.Countdown.rang ? Theme.warn : Theme.fg
            }
        }

        // ----------------------------------------------------------- status pill
        // The one thing on the notch that answers a click.
        Pill {
            interactive: true
            Layout.alignment: Qt.AlignVCenter
            onClicked: Ipc.toggle("quick")

            RowLayout {
                spacing: Theme.space2

                RowLayout {
                    spacing: Theme.space1
                    visible: Services.Net.available
                    Icon {
                        text: Services.Net.icon
                        size: Theme.fontSize
                        color: Theme.accent
                    }
                    SignalBars {
                        visible: Services.Net.kind === "wifi"
                        level: Services.Net.level
                        // ⚠️ `activeColour`, not `color` — SignalBars is an Item
                        // with two colours, and assigning `color` to an Item is
                        // accepted and painted by nobody.
                        activeColour: Theme.accent
                    }
                }
    }

            RowLayout {
                spacing: Theme.space1
                visible: Services.Power.available
                Icon {
                    text: Services.Power.charging ? "battery_charging_full"
                                                  : "battery_full"
                    size: Theme.fontSize
                    // Accent is the resting colour here — the pill is the accent
                    // element on the reference. A battery in trouble still
                    // outranks it, because that is the one time the colour is
                    // carrying information rather than style.
                    color: Services.Power.critical ? Theme.error
                         : Services.Power.low ? Theme.warn
                         : Theme.accent
                }
                BarText {
                    text: Math.round(Services.Power.percent) + "%"
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.accent
                }
            }

            // ⚠️ A machine with neither network nor battery — the test VM is
            // exactly that — would otherwise get an empty pill, which is the one
            // thing the brief rules out. It keeps the pill's job (open the quick
            // panel) and says so with a symbol instead of standing there blank.
            Icon {
                visible: !Services.Net.available && !Services.Power.available
                text: "expand_more"
                size: Theme.fontSize
                color: Theme.accent
            }
        }
    }
}
