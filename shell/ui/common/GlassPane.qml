// A translucent panel that reads as a pane of glass.
//
// What makes glass look like glass is its EDGE. The middle of a translucent
// panel is just blurred backdrop, and the compositor already produces that —
// once, cheaply, via niri's xray blur. So everything here is about the border:
// a rim that is bright along the top where light would land, weak along the
// sides, and returning faintly along the bottom, plus a sheen lying over the
// upper part of the pane.
//
// ⚠️ WHY THERE IS NO SHADER HERE. Refraction — the thing that actually bends
// what is behind the glass — needs to sample the backdrop, and a layer surface
// cannot see its own backdrop. Only the compositor can. A shader in here would
// have to draw and blur its own copy of the wallpaper in order to refract it,
// which duplicates the one thing niri does for free and pays for it on every
// frame. On a laptop that trade is the wrong way round. hyprglass does real
// refraction because it runs inside Hyprland's render pipeline; niri has no
// plugin interface, so that road is closed rather than merely harder.
//
// The construction is two rounded rectangles, not a border:
// `Rectangle.border.color` is one flat colour, and a rim of one flat colour is
// exactly what makes a panel look printed rather than lit. So the outer
// rectangle carries a vertical gradient and the body sits one hairline inside
// it, leaving that gradient visible as a ring.
//
// Cost: two extra draws, no per-frame work, nothing running when the surface is
// closed. `look.glass false` (or `look.profile minimal`) removes both.

import QtQuick
import "../../theme"

Item {
    id: root

    // The body colour. Callers pass their own so a bar, a card and a page can
    // differ in tint without each re-deriving what "glass" means.
    property color fill: Theme.panelBg
    property int radius: Theme.radiusLg

    // Corners have to shrink with the inset, or the body's corner cuts across
    // the rim and the ring goes thick at the four corners and thin everywhere
    // else — which reads as a rendering fault rather than as a highlight.
    readonly property int innerRadius: Math.max(0, radius - Theme.hairline)

    Rectangle {
        id: rim
        anchors.fill: parent
        radius: root.radius
        visible: Theme.glass
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.glassRimTop }
            GradientStop { position: 0.45; color: Theme.glassRimSide }
            GradientStop { position: 1.0; color: Theme.glassRimBottom }
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        anchors.margins: Theme.glass ? Theme.hairline : 0
        radius: Theme.glass ? root.innerRadius : root.radius
        color: root.fill
    }

    // The sheen. It stops well before the middle: any further and it stops
    // reading as light on a surface and starts reading as a lighter background.
    Rectangle {
        anchors.fill: body
        radius: body.radius
        visible: Theme.glass
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.glassSheen }
            GradientStop { position: 0.38; color: "transparent" }  // literal-ok: absence of colour
        }
    }
}
