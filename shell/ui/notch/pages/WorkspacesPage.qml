pragma ComponentBehavior: Bound

// Every workspace and what is on it, small, on top of the desktop you are using.
//
// His words: "eine übersicht über alle workspaces … eine miniatur ansicht an     english-ok: the request, quoted
// allen workspaces und ich kann programme mit der maus von einem in den anderen  english-ok: the request, quoted
// workspace verschieben" — and, on being asked, a small panel on the running     english-ok: the request, quoted
// desktop rather than a full-screen overview.
//
// ⚠️ THERE ARE NO PICTURES IN HERE, AND THAT IS NOT LAZINESS. A Wayland client
// may not read another window's contents. The only capture protocol available,
// wlr-screencopy, records the OUTPUT that is currently on screen — not the other
// workspaces, which the compositor is not drawing at all. A thumbnail grid built
// from it would show one real picture and empty boxes for everything else.
//
// So this draws what the compositor DOES tell us, and it turns out to be enough
// to recognise a workspace at a glance:
//
//   niri msg -j windows      app_id · title · id · workspace_id · is_focused
//                            · is_floating · layout
//   niri msg -j workspaces   id · idx · name · is_active · output
//
// ⚠️ AND `layout` IS WHY THE BOXES ARE IN THE RIGHT PLACES. It carries
// `pos_in_scrolling_layout: [column, row]` and `tile_size`, measured on the
// machine rather than assumed — so a column that is half as wide is drawn half
// as wide, and three windows side by side look like three windows side by side.
//
// ⚠️ Everything comes from `Services.Compositor`, which is fed by niri's
// event-stream. No polling: a map that costs CPU while nobody is looking at it
// is the kind of idle work this desktop is not allowed to do.

import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../config"
import "../../../ipc"
import "../../../services" as Services
import "../../common"

ColumnLayout {
    id: root

    spacing: Theme.space3

    // How tall one workspace box is. The width follows from the columns in it,
    // so a busy workspace is a wider box — which is itself information.
    //
    // ⚠️ IT WAS `space6 * 3` AND THAT WAS TOO SMALL TO USE — reported exactly
    // that way about the switcher. `space6` is 32, so a workspace was a 64×96
    // box holding 24 px window tiles with 13 px icons on them. At that size the
    // tiles are colour, not information: you cannot tell a terminal from a
    // browser, which is the one question this surface exists to answer.
    //
    // Doubled, and the tiles and icons with it — see the tile below. It stays
    // derived from the spacing scale rather than becoming a key of its own, so
    // the `look.uiScale` slider still moves it along with everything else.
    readonly property int boxHeight: Theme.space6 * 6

    // The workspaces, each with its own windows already gathered. Done once
    // here rather than filtered again inside every delegate: with n workspaces
    // and m windows the naive way is n×m passes on every single event.
    readonly property var groups: {
        var byWs = ({})
        var all = Services.Compositor.windows || []
        for (var i = 0; i < all.length; i++) {
            var w = all[i]
            var k = String(w.workspace_id)
            if (!byWs[k])
                byWs[k] = []
            byWs[k].push(w)
        }
        // Real order: column first, then row. `pos_in_scrolling_layout` is
        // [column, row], both 1-based.
        for (var k2 in byWs) {
            byWs[k2].sort(function (a, b) {
                var pa = (a.layout && a.layout.pos_in_scrolling_layout) || [0, 0]
                var pb = (b.layout && b.layout.pos_in_scrolling_layout) || [0, 0]
                return pa[0] !== pb[0] ? pa[0] - pb[0] : pa[1] - pb[1]
            })
        }
        var out = []
        var ws = Services.Compositor.workspaces || []
        for (var j = 0; j < ws.length; j++)
            out.push({ ws: ws[j], windows: byWs[String(ws[j].id)] || [] })
        return out
    }

    // Which box the pointer is over while dragging, so it can light up. -1 is
    // "none" rather than 0, which is a real index.
    property int dropTarget: -1

    BarText {
        text: "Workspaces"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    RowLayout {
        id: row
        spacing: Theme.space3

        Repeater {
            model: root.groups

            // ------------------------------------------------ one workspace
            Rectangle {
                id: box
                required property var modelData
                required property int index

                implicitWidth: Math.max(Theme.space6 * 4,
                                        tiles.implicitWidth + Theme.space2 * 2)
                implicitHeight: root.boxHeight
                radius: Theme.radiusSm
                // The workspace you are on is the accent one. A drop target
                // outranks it while a drag is happening — during a drag the
                // question is "where will it land", not "where am I".
                color: root.dropTarget === box.index ? Theme.accent
                     : box.modelData.ws.is_active ? Theme.surfaceHigh
                     : Theme.surface
                border.width: Theme.hairline
                border.color: box.modelData.ws.is_focused ? Theme.accent
                                                          : Theme.outline

                Behavior on color {
                    enabled: Theme.animate
                    ColorAnimation { duration: Theme.durFast }
                }

                // Clicking the box goes to that workspace — the map is also a
                // switcher, which is what you want nine times out of ten.
                TapHandler {
                    onTapped: {
                        Services.Compositor.focusWorkspace(box.modelData.ws.idx)
                        Ipc.collapse()
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.space1
                    spacing: 0   // literal-ok: absence of a gap

                    BarText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: box.modelData.ws.name
                              ? String(box.modelData.ws.name)
                              : String(box.modelData.ws.idx)
                        font.pixelSize: Theme.fontSizeSm
                        color: root.dropTarget === box.index ? Theme.accentFg
                                                             : Theme.fgMuted
                    }

                    // ------------------------------------- the windows in it
                    RowLayout {
                        id: tiles
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Theme.space1

                        BarText {
                            visible: box.modelData.windows.length === 0
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            // An empty workspace says so. A blank box reads as
                            // something that failed to load.
                            text: "empty"
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.fgDim
                        }

                        Repeater {
                            model: box.modelData.windows

                            Rectangle {
                                id: tile
                                required property var modelData

                                // Proportional to the real tile, so a narrow
                                // column looks narrow. Clamped, because a
                                // window can legitimately be 3000 px wide and
                                // this box is not.
                                readonly property real w:
                                    (modelData.layout && modelData.layout.tile_size)
                                        ? modelData.layout.tile_size[0] : 1
                                // ⚠️ The divisor and both clamps moved with the
                                // box height. At /24 with a 24..64 px clamp a
                                // 1920 px window came out 64 px wide and a
                                // 640 px one came out 27 — nearly everything
                                // landed on a clamp, so the proportion the
                                // comment above promises was mostly not there.
                                // At /12 with 32..128 the middle of the range
                                // is where real windows actually sit.
                                Layout.preferredWidth:
                                    Math.max(Theme.space6, Math.min(Theme.space6 * 4,
                                             tile.w / 12))
                                Layout.fillHeight: true
                                radius: Theme.radiusXs
                                color: modelData.is_focused ? Theme.accentAlt
                                                            : Theme.surfaceHigh
                                opacity: drag.active ? 0.5 : 1

                                // ⚠️ `source` AND `appName`, not `appId` —
                                // AppIcon takes the freedesktop name and falls
                                // back to the first letter. niri's `app_id` IS
                                // that name in nearly every case (kitty,
                                // org.gnome.Nautilus, brave-browser), and where
                                // it is not, the fallback catches it.
                                AppIcon {
                                    anchors.centerIn: parent
                                    source: tile.modelData.app_id || ""
                                    appName: tile.modelData.app_id || ""
                                    // ⚠️ Was `fontSizeLg`, which is 13 px — an
                                    // icon that small is a coloured smudge, and
                                    // telling one window from another is the
                                    // whole job here. Never wider than the tile
                                    // it sits on, so a narrow column still gets
                                    // an icon that fits rather than one that
                                    // overhangs.
                                    size: Math.min(Theme.space5,
                                                   tile.width - Theme.space1 * 2)
                                }

                                // Click focuses that window, wherever it is.
                                TapHandler {
                                    onTapped: {
                                        Services.Compositor.focusWindow(tile.modelData.id)
                                        Ipc.collapse()
                                    }
                                }

                                // ⚠️ THE DRAG, and it deliberately does NOT
                                // reparent or animate the tile anywhere. Moving
                                // a QML item between two Repeater delegates
                                // while the model underneath is being rewritten
                                // by a compositor event is a fight nobody wins.
                                // The tile fades, the target box lights up, and
                                // the actual move is niri's job.
                                DragHandler {
                                    id: drag
                                    onActiveChanged: {
                                        if (drag.active) {
                                            root.dropTarget = -1
                                            return
                                        }
                                        var t = root.dropTarget
                                        root.dropTarget = -1
                                        if (t < 0 || t >= root.groups.length)
                                            return
                                        var target = root.groups[t].ws
                                        if (target.id === tile.modelData.workspace_id)
                                            return
                                        // ⚠️ `idx`, not `id` — niri's reference
                                        // is the INDEX. They differ: here the
                                        // workspaces are idx 1/2/3 with ids
                                        // 1/3/4.
                                        Services.Compositor.moveWindowToWorkspace(
                                            tile.modelData.id, target.idx)
                                    }
                                    onCentroidChanged: {
                                        if (!drag.active)
                                            return
                                        var p = tile.mapToItem(root, drag.centroid.position.x,
                                                               drag.centroid.position.y)
                                        root.dropTarget = root.boxAt(p.x, p.y)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Which workspace box a point is over. Plain geometry rather than
    // DropArea: a DropArea per box would need the drag to carry MIME data,
    // which is a lot of ceremony for "is the pointer inside this rectangle".
    function boxAt(x, y) {
        for (var i = 0; i < row.children.length; i++) {
            var c = row.children[i]
            if (c.x <= x && x <= c.x + c.width && c.y <= y && y <= c.y + c.height)
                return i
        }
        return -1
    }
}
