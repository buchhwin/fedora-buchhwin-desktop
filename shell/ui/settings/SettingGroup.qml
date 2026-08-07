// A titled block of rows.
//
// Grouping by SPACE and a small heading, never by a line. Rule three of the
// brief: "Trennung durch Abstand und Fläche, nicht durch Linien. Höchstens eine   english-ok: the brief, quoted
// Trennlinie je Ansicht, und nur wo Gruppen sonst verschmelzen." Eighteen rows    english-ok: the brief, quoted
// on one page is exactly where that would start to slip.
//
// The heading is small, muted and semibold — the second of the two sizes a
// surface is allowed, with the row labels being the first.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme"

ColumnLayout {
    id: root

    property string title: ""

    // ⚠️ `.data`, not `.children`. Anything that is not an Item — a Connections,
    // a Timer a group might one day carry — has no place in `children` and
    // would be dropped without a word.
    default property alias content: holder.data

    spacing: Theme.space3

    BarText {
        visible: root.title.length > 0
        text: root.title
        font.pixelSize: Theme.fontSizeSm
        font.weight: Theme.weightSemibold
        color: Theme.fgMuted
    }

    ColumnLayout {
        id: holder
        Layout.fillWidth: true
        // Wider than the gap inside a row, so a row reads as one thing and the
        // gap between two rows reads as the join.
        spacing: Theme.space4
    }
}
