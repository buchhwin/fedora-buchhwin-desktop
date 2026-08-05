// Setting where this machine is — the one place it is done.
//
// A component rather than markup inside the quick panel, because the settings
// window will need exactly this on its System page. Two copies would drift:
// one would get the confirm button, the other would keep the old placeholder,
// and both would sit in the same product disagreeing about how it works.
//
// The shape of it comes from one decision: the timezone already gives a good
// guess, so most people should never type anything. It is OFFERED, not
// asserted — a timezone names its reference city, not yours, and silently
// showing Berlin's weather to somebody in Stuttgart is the worst kind of wrong.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services" as Services

ColumnLayout {
    id: root
    spacing: Theme.space2

    // The panel shows this compactly; the settings window will want it roomy.
    property bool compact: false

    // ------------------------------------------------------- what we have now
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space2
        visible: Services.Location.known && !editing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0        // literal-ok: absence of a gap — name and origin
                              // are one label on two lines, not two things
            BarText {
                Layout.fillWidth: true
                text: Services.Location.name
                elide: Text.ElideRight
            }
            BarText {
                visible: Services.Location.guessed
                text: "aus der Zeitzone geraten"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
            }
        }

        // The single click the whole design is built around: if the guess is
        // right, confirming it is the entire setup.
        Pill {
            interactive: true
            active: true
            visible: Services.Location.guessed
            BarText {
                text: "stimmt"
                font.pixelSize: Theme.fontSizeSm
                color: Theme.accentFg
            }
            TapHandler { onTapped: Services.Location.confirm() }
        }

        Pill {
            interactive: true
            Icon { text: "edit"; size: Theme.fontSizeLg }
            TapHandler {
                onTapped: {
                    root.editing = true
                    field.text = ""
                    field.forceActiveFocus()
                }
            }
        }
    }

    property bool editing: false

    // ------------------------------------------------------------- searching
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.space1
        visible: !Services.Location.known || root.editing

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.space6
            radius: Theme.radiusSm
            color: Theme.surface
            border.width: field.activeFocus ? Theme.space1 / 2 : 0
            border.color: Theme.accent

            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: Theme.space2
                anchors.rightMargin: Theme.space2
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSize
                color: Theme.fg
                selectionColor: Theme.accent
                selectedTextColor: Theme.accentFg
                selectByMouse: true
                clip: true
                onTextChanged: Services.Location.search(text)
                Keys.onEscapePressed: root.editing = false
            }

            BarText {
                anchors { left: parent.left; leftMargin: Theme.space2
                          verticalCenter: parent.verticalCenter }
                visible: field.text.length === 0
                text: "Stadt eingeben"
                color: Theme.fgDim
            }
        }

        Repeater {
            model: Services.Location.matches

            Pill {
                id: hit
                required property var modelData
                Layout.fillWidth: true
                interactive: true
                BarText {
                    text: hit.modelData.name
                          + (hit.modelData.admin && hit.modelData.admin.length
                             ? " · " + hit.modelData.admin : "")
                          + (hit.modelData.country && hit.modelData.country.length
                             ? " · " + hit.modelData.country : "")
                    font.pixelSize: Theme.fontSizeSm
                    elide: Text.ElideRight
                }
                TapHandler {
                    onTapped: {
                        Services.Location.choose(hit.modelData)
                        root.editing = false
                    }
                }
            }
        }

        BarText {
            Layout.fillWidth: true
            visible: Services.Location.searching || Services.Location.status.length > 0
            text: Services.Location.searching ? "sucht …" : Services.Location.status
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
        }
    }
}
