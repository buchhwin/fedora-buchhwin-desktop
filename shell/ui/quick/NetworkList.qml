// The wifi networks, and the one place in this shell that asks for a password.
//
// ⚠️ THE SCANNER IS TIED TO THIS COMPONENT'S LIFETIME. It exists only while the
// wifi tile is expanded, so switching the radio scan on in onCompleted and off
// in onDestruction is the whole of the policy — no timer, no flag to forget.
// See services/Net.qml for why a scan running in the background is not free.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services" as Services
import "../common"

ColumnLayout {
    id: root

    spacing: Theme.space1

    Component.onCompleted: Services.Net.watch(true)
    Component.onDestruction: Services.Net.watch(false)

    // Which row has its password field open. The name rather than the index:
    // the list re-sorts itself as signal strengths move, and an index would
    // follow the position instead of the network.
    property string asking: ""

    BarText {
        Layout.fillWidth: true
        visible: !Services.Net.wifiEnabled
        text: "Wi-Fi is off"
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Net.wifiEnabled && Services.Net.networks.length === 0
        text: Services.Net.scanning ? "Looking for networks …" : "No networks in range"
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }

    Repeater {
        model: Services.Net.wifiEnabled ? Services.Net.networks : []

        ColumnLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.space1

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: line.implicitHeight + Theme.space2 * 2
                radius: Theme.radiusSm
                color: rowHover.hovered ? Theme.pillHover : "transparent"  // literal-ok: absence of colour

                HoverHandler { id: rowHover }
                TapHandler {
                    onTapped: {
                        if (row.modelData.connected) {
                            Services.Net.disconnect(row.modelData)
                        } else if (Services.Net.needsPassword(row.modelData)) {
                            // Asking is not connecting: the field opens, and
                            // nothing is attempted until it is answered.
                            root.asking = root.asking === row.modelData.name
                                ? "" : row.modelData.name
                        } else {
                            Services.Net.connect(row.modelData)
                        }
                    }
                }

                RowLayout {
                    id: line
                    anchors.fill: parent
                    anchors.margins: Theme.space2
                    spacing: Theme.space3

                    SignalBars {
                        level: row.modelData.level
                        size: Theme.fontSizeLg
                    }

                    BarText {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.weight: row.modelData.connected ? Theme.weightMedium
                                                             : Theme.weightNormal
                    }

                    // A lock says it needs a password; nothing says it does not.
                    // No badge for "known", because the word "connected" and the
                    // weight of the name already carry that.
                    Icon {
                        visible: row.modelData.secured
                        text: "wifi_lock"
                        size: Theme.fontSize
                        color: Theme.fgDim
                    }

                    BarText {
                        visible: row.modelData.connected || row.modelData.busy
                        text: row.modelData.busy ? "…" : "connected"
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.accent
                    }

                    Pill {
                        visible: row.modelData.known && !row.modelData.connected
                        interactive: true
                        Icon { text: "link_off"; size: Theme.fontSize; color: Theme.fgDim }
                        onClicked: Services.Net.forget(row.modelData)
                    }
                }
            }

            // The password field, open only for the row that asked for it.
            RowLayout {
                Layout.fillWidth: true
                visible: root.asking === row.modelData.name
                spacing: Theme.space2

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: secret.implicitHeight + Theme.space2 * 2
                    radius: Theme.radiusSm
                    color: Theme.surfaceHigh

                    TextInput {
                        id: secret
                        anchors.fill: parent
                        anchors.margins: Theme.space2
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.fg
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fontSize
                        // ⚠️ The password is never echoed and never stored. It
                        // goes straight into one nmcli call and the field is
                        // cleared — see Net.connectWithPassword.
                        echoMode: TextInput.Password
                        onAccepted: {
                            Services.Net.connectWithPassword(row.modelData, secret.text)
                            secret.text = ""
                            root.asking = ""
                        }

                        // Opening the field and then having to click it would be
                        // one step too many for something you opened in order to
                        // type into.
                        onVisibleChanged: if (visible) secret.forceActiveFocus()
                        Component.onCompleted: secret.forceActiveFocus()
                    }
                }

                Pill {
                    interactive: true
                    active: secret.text.length > 0
                    BarText {
                        text: "join"
                        font.pixelSize: Theme.fontSizeSm
                        color: secret.text.length > 0 ? Theme.accentFg : Theme.fgDim
                    }
                    onClicked: {
                        if (secret.text.length === 0)
                            return
                        Services.Net.connectWithPassword(row.modelData, secret.text)
                        secret.text = ""
                        root.asking = ""
                    }
                }
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Net.status.length > 0
        text: Services.Net.status
        color: Theme.error
        font.pixelSize: Theme.fontSizeSm
        wrapMode: Text.WordWrap
    }
}
