// The media page: what the island becomes when you ask it about music.
//
// Bigger than the bar pill on purpose — this is the expanded form, so it can
// afford the artwork at a readable size and the transport controls the pill
// deliberately leaves out.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services" as Services
import "../../common"

RowLayout {
    id: root
    spacing: Theme.space4
    implicitWidth: Theme.space6 * 16

    Rectangle {
        implicitWidth: Theme.space6 * 2
        implicitHeight: Theme.space6 * 2
        radius: Theme.radiusMd
        color: Theme.surfaceHigh
        clip: true

        Image {
            anchors.fill: parent
            source: Services.Media.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: Services.Media.artUrl.length > 0
        }

        Icon {
            anchors.centerIn: parent
            visible: Services.Media.artUrl.length === 0
            text: "music_note"
            size: Theme.fontSizeXl
            color: Theme.fgDim
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.space1

        BarText {
            Layout.fillWidth: true
            text: Services.Media.available ? Services.Media.title : "Nichts läuft gerade"
            font.pixelSize: Theme.fontSizeLg
            font.weight: Theme.weightSemibold
        }

        BarText {
            Layout.fillWidth: true
            visible: Services.Media.artist.length > 0
            text: Services.Media.artist
            color: Theme.fgMuted
        }
    }

    Pill {
        interactive: Services.Media.canToggle
        visible: Services.Media.available

        Icon {
            text: Services.Media.playing ? "pause" : "play_arrow"
            size: Theme.fontSizeXl
        }

        TapHandler {
            enabled: Services.Media.canToggle
            onTapped: Services.Media.toggle()
        }
    }
}
