// A translucent panel that reads as a pane of glass.
//
// What makes glass look like glass is its EDGE. The middle of a translucent
// panel is just blurred backdrop, and the compositor already produces that —
// once, cheaply, via niri's xray blur. So everything here is about the edge: a
// sheen lying over the upper part of the pane, and a fine glint along the
// bottom where light bounces back up through it.
//
// ⚠️ THERE IS NO RING. There was one — a gradient rectangle behind the body,
// showing as a hairline all the way round — and it was reported as "the quick
// panel still has a border round it, that should go". Going back to the two
// reference screenshots settles it: neither shows a ring. Both show one thing
// only, "a fine lighter line along the bottom edge". So the top and side rim
// tokens are gone rather than dimmed, because a rim nobody can see is two draws
// nobody pays for on purpose.
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
// Cost: one extra draw for the sheen and one for the glint, no per-frame work,
// nothing running when the surface is closed. `look.glass false` (or
// `look.profile minimal`) removes both and leaves the plain body.

import QtQuick
import "../../theme"

Item {
    id: root

    // The body colour. Callers pass their own so a bar, a card and a page can
    // differ in tint without each re-deriving what "glass" means.
    property color fill: Theme.panelBg
    property int radius: Theme.radiusLg

    Rectangle {
        id: body
        anchors.fill: parent
        radius: root.radius
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

    // The glint, and the whole of the edge treatment that is left.
    //
    // ⚠️ Inset by the corner radius on both sides. A line drawn the full width
    // would run out past where the body has already curved away, and the two
    // stubs sticking out of the corners are the one thing that looks like a
    // fault rather than like light.
    Rectangle {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: root.radius
            rightMargin: root.radius
        }
        height: Theme.hairline
        visible: Theme.glass
        color: Theme.glassRimBottom
    }
}
