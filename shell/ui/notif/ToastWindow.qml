// One layer surface holding exactly one toast.
//
// ⚠️ THE SURFACE IS EXACTLY AS BIG AS WHAT IT DRAWS. niri draws shadow and blur
// behind the whole layer surface, invisible margins included — see the note in
// ToastSurface.qml for the band of shadow that appeared between two cards when
// they shared one window.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"

PanelWindow {
    id: root

    required property var notification
    required property int index

    WlrLayershell.namespace: "buchhwin-toast"
    // `top`, like the notch: above ordinary windows, below a fullscreen one.
    // A message is not important enough to sit over a video, and the ones that
    // are stay on screen until dismissed anyway.
    WlrLayershell.layer: WlrLayer.Top

    anchors { top: true; right: true }
    margins {
        right: Theme.space4
        // Stacked downwards from the top edge. Every card is the same height,
        // which is what lets a window know where it belongs without waiting for
        // its neighbours to be laid out.
        top: Theme.space4 + root.index * (card.implicitHeight + Theme.space2)
    }

    // Sliding the WINDOW rather than the card inside it: the surface is the
    // size of the card, so there is no room to move within it.
    Behavior on margins.top {
        enabled: Theme.animate
        NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"                    // literal-ok: absence of colour

    implicitWidth: Math.max(1, card.implicitWidth)
    implicitHeight: Math.max(1, card.implicitHeight)

    mask: Region { item: card }

    Toast {
        id: card
        anchors.fill: parent
        notification: root.notification
    }
}
