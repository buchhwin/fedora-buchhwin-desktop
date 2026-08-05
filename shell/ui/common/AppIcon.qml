// A program's own icon, from the icon theme — the one place in this shell
// where an icon is a picture rather than a glyph.
//
// ⚠️ AND IT IS THE EXCEPTION, NOT A NEW RULE. common/Icon.qml argues for an
// icon font, and that argument stands for everything the shell draws itself: a
// glyph inherits the palette, so it can never be the one element that did not
// follow a theme change. A program's icon is different in kind — it is Firefox's
// own mark, not our decoration, and recolouring it would make it unrecognisable.
//
// Quickshell.iconPath() resolves a freedesktop icon name against the current
// icon theme (Papirus here, installed by packages/dnf-desktop.txt). Two things
// it does not do: guarantee the name exists, or invent one when the .desktop
// file has none. Both are ordinary — a program with no icon is not broken — so
// the fallback is a glyph and the first letter, never an empty box.
import QtQuick
import Quickshell
import "../../theme"

Item {
    id: root

    // The freedesktop icon name out of the .desktop file, possibly empty.
    property string source: ""
    // The program's name, for the initial in the fallback.
    property string appName: ""
    property int size: Theme.fontSizeXl

    implicitWidth: size
    implicitHeight: size

    // ⚠️ Asked before it is used. iconPath() on an unknown name returns an
    // empty string, and Image would then show nothing at all with no error —
    // the same silent-empty failure as a missing glyph, and the reason
    // tests/icons.sh exists for the font side.
    readonly property string resolved:
        root.source.length && Quickshell.hasThemeIcon(root.source)
            ? Quickshell.iconPath(root.source) : ""

    Image {
        anchors.fill: parent
        visible: root.resolved.length > 0
        source: root.resolved
        // Decode at the size actually drawn. A 512-pixel PNG scaled into 28
        // logical pixels costs the full decode and the memory of the original,
        // for every program in the list at once.
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        cache: true
    }

    // No icon: the first letter on a plain tile. Recognisable enough to tell
    // two rows apart, and honest about being a stand-in.
    Rectangle {
        anchors.fill: parent
        visible: root.resolved.length === 0
        radius: Theme.radiusSm
        color: Theme.surfaceHigh

        Text {
            anchors.centerIn: parent
            text: root.appName.length ? root.appName.charAt(0).toUpperCase() : "?"
            font.family: Theme.fontUi
            font.pixelSize: Math.round(root.size * 0.55)
            font.weight: Theme.weightSemibold
            color: Theme.fgMuted
        }
    }
}
