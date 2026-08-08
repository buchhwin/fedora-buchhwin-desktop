// The fourth view of the quick panel: the switches and levels you reach for
// without thinking — network, bluetooth, night light, do not disturb, the
// microphone, the bar — and the sound and brightness underneath them.
//
// ⚠️ ONE THING OPENS AT A TIME. Wifi, bluetooth and sound each have a list
// behind them, and letting all three stand open would make a panel taller than
// the screen out of a surface that is supposed to be glanced at. `open` names
// the one that is out; pressing another chevron swaps them.
//
// ⚠️ AND A CLOSED LIST DOES NOT EXIST. The Loader below has no component while
// `open` is empty, so the wifi scan, the bluetooth discovery and the pipewire
// node tracking are not merely hidden — they were never started. Each list
// switches its own service on in onCompleted and off in onDestruction, which is
// why that policy needs no bookkeeping here.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../config"
import "../../ipc"
import "../../services" as Services
import "../common"

ColumnLayout {
    id: root

    spacing: Theme.space3
    implicitWidth: Theme.space6 * 19

    // "", "wifi", "bt" or "sound".
    property string open: ""
    // ⚠️ A NAMED PROPERTY RATHER THAN THE COMPARISON INLINE, and the reason is
    // the icon tripwire: tests/icons.sh takes every quoted string on an
    // `Icon { text: … }` line as an icon name, so `root.open === "sound" ?
    // "expand_less" : "expand_more"` asks the font for a glyph called "sound".
    // It is also easier to read.
    readonly property bool soundOpen: root.open === "sound"

    // ⚠️ SO ESC CAN CLOSE THE DRAWER BEFORE THE PANEL. "auch bei allen             // english-ok: quoted brief
    // unterfenstern" — with a WiFi list open, Esc closing the whole panel throws
    // away two steps of navigation at once, and there is no way back to where
    // you were. Returns whether it had anything to close, so the caller knows
    // whether to keep going.
    function closeDrawer() {
        if (root.open.length === 0)
            return false
        root.open = ""
        return true
    }

    function show(which) {
        root.open = root.open === which ? "" : which
    }

    // ------------------------------------------------------------- the tiles
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Theme.space2
        rowSpacing: Theme.space2

        Tile {
            Layout.fillWidth: true
            visible: Services.Net.available
            icon: Services.Net.icon
            title: "Wi-Fi"
            // The question the panel is opened to answer, on the tile itself.
            subtitle: !Services.Net.wifiPresent ? Services.Net.kind === "wired"
                                                  ? Services.Net.wiredName : "no adapter"
                    : Services.Net.wifiBlocked ? "blocked in hardware"
                    : !Services.Net.wifiEnabled ? "off"
                    : Services.Net.ssid.length ? Services.Net.ssid
                    : "not connected"
            active: Services.Net.wifiEnabled && Services.Net.wifiPresent
            usable: Services.Net.wifiPresent && !Services.Net.wifiBlocked
            expandable: Services.Net.wifiPresent
            expanded: root.open === "wifi"
            onClicked: Services.Net.setWifi(!Services.Net.wifiEnabled)
            onExpandClicked: root.show("wifi")
        }

        Tile {
            Layout.fillWidth: true
            visible: Services.Bt.available
            icon: Services.Bt.icon
            title: "Bluetooth"
            subtitle: !Services.Bt.enabled ? "off"
                    : Services.Bt.connectedDevices.length > 0
                      ? Services.Bt.connectedDevices[0].name
                      : "nothing connected"
            active: Services.Bt.enabled
            expandable: true
            expanded: root.open === "bt"
            onClicked: Services.Bt.setEnabled(!Services.Bt.enabled)
            onExpandClicked: root.show("bt")
        }

        Tile {
            Layout.fillWidth: true
            icon: "nights_stay"
            title: "Night light"
            // The one case where the subtitle is a warning: gammastep starts,
            // says the screen has no gamma control and then does nothing. A
            // switch that lights up and changes nothing is what this avoids.
            subtitle: !Services.Nightlight.supported ? Services.Nightlight.status
                    : !Services.Nightlight.available ? "gammastep is missing"
                    : Services.Nightlight.on
                      ? Services.Nightlight.temperature + " K" : "off"
            active: Services.Nightlight.on && Services.Nightlight.supported
            usable: Services.Nightlight.available && Services.Nightlight.supported
            onClicked: Services.Nightlight.toggle()
        }

        Tile {
            Layout.fillWidth: true
            icon: Config.notifications.dnd ? "notifications_off" : "notifications"
            title: "Do not disturb"
            subtitle: Config.notifications.dnd ? "toasts silenced" : "off"
            active: Config.notifications.dnd
            onClicked: {
                Config.notifications.dnd = !Config.notifications.dnd
                Config.save()
            }
        }

        Tile {
            Layout.fillWidth: true
            visible: Services.Audio.micAvailable
            icon: Services.Audio.micMuted ? "mic_off" : "mic"
            title: "Microphone"
            subtitle: Services.Audio.micMuted ? "muted" : "on"
            // ⚠️ Accent means MUTED here, which is the opposite of the other
            // tiles, and it is deliberate: the state worth marking is the one
            // that surprises you in a meeting.
            active: Services.Audio.micMuted
            onClicked: Services.Audio.toggleMicMute()
        }

        Tile {
            Layout.fillWidth: true
            icon: "view_agenda"
            title: "Top bar"
            subtitle: Config.bar.enabled ? "on" : "off"
            active: Config.bar.enabled
            onClicked: {
                Config.bar.enabled = !Config.bar.enabled
                Config.save()
            }
        }
    }

    // ------------------------------------------------------------ the drawer
    Loader {
        Layout.fillWidth: true
        active: root.open !== ""
        // ⚠️ SYNCHRONOUS ON PURPOSE. What this loader builds decides the size of
        // the card, and the card decides the size of the layer surface. Loading
        // it a frame late means the surface is configured at one size and then
        // re-configured when the content lands — a round trip with niri and a
        // new buffer, and on screen a panel that opens at the wrong size and
        // grows while you look at it. It is one small view, not the twenty-one
        // settings pages whose synchronous build was a real freeze.
        asynchronous: false
        sourceComponent: root.open === "wifi" ? networkList
                       : root.open === "bt" ? bluetoothList
                       : root.open === "sound" ? soundList
                       : null

        // Comes down rather than appearing, at the same pace as everything
        // else. The surface around it is already animating its own height.
        opacity: root.open !== "" ? 1 : 0
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
    }

    Component { id: networkList; NetworkList {} }
    Component { id: bluetoothList; BluetoothList {} }
    Component { id: soundList; SoundList {} }

    // ----------------------------------------------------------- the levels
    RowLayout {
        Layout.fillWidth: true
        visible: Services.Audio.available
        spacing: Theme.space2

        LevelRow {
            fat: true
            Layout.fillWidth: true
            icon: Services.Audio.muted ? "volume_off"
                : Services.Audio.volume > 0.5 ? "volume_up" : "volume_down"
            value: Services.Audio.volume
            live: !Services.Audio.muted
            onMoved: function (f) { Services.Audio.setVolume(f) }
            onNudged: function (d) {
                Services.Audio.setVolume(Services.Audio.volume + d / steps)
            }
        }

        // The way to the outputs and the per-programme levels. It sits on the
        // volume row rather than being a seventh tile, because that is where
        // somebody looks when the sound is coming out of the wrong thing.
        Pill {
            interactive: true
            active: root.soundOpen
            Icon {
                text: root.soundOpen ? "expand_less" : "expand_more"
                size: Theme.fontSizeLg
                color: root.soundOpen ? Theme.accentFg : Theme.fg
            }
            onClicked: root.show("sound")
        }
    }

    LevelRow {
        fat: true
        Layout.fillWidth: true
        visible: Services.Brightness.available
        icon: "brightness_6"
        value: Services.Brightness.fraction
        onMoved: function (f) { Services.Brightness.set(f) }
        onNudged: function (d) {
            Services.Brightness.set(Math.max(0.01, Math.min(1,
                Services.Brightness.fraction + d / steps)))
        }
    }

    // The external monitor, and ONLY when one answered. It is a second row
    // rather than a mode on the first because both screens can be lit at once
    // and both are worth reaching — a single slider would have to pick one and
    // be wrong half the time. The symbol differs so the two rows are telling
    // apart at a glance rather than by position.
    //
    // ⚠️ `onReleased` when Config says not to send live: a DDC write is slow
    // and many monitors flash their own menu for each one. See the head of
    // services/Brightness.qml for what is measured here and what is not.
    LevelRow {
        fat: true
        Layout.fillWidth: true
        visible: Services.Brightness.externalAvailable
        icon: "desktop_windows"
        value: Services.Brightness.externalFraction
        onMoved: function (f) { Services.Brightness.setExternal(f) }
        onReleased: function (f) { Services.Brightness.commitExternal() }
        onNudged: function (d) {
            Services.Brightness.setExternal(Math.max(0, Math.min(1,
                Services.Brightness.externalFraction + d / steps)))
            // A wheel notch has no "release" of its own — it is a whole gesture
            // in one event, so it commits itself. Without this the monitor
            // would ignore the wheel entirely whenever live sending is off.
            Services.Brightness.commitExternal()
        }
    }

    BarText {
        Layout.fillWidth: true
        visible: !Services.Audio.available && !Services.Brightness.available
        text: "No sound or backlight on this machine"
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }
}
