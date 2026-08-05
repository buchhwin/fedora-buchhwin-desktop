pragma Singleton

// Screen backlight, or the honest absence of one.
//
// There is no Wayland protocol for this, so it goes through brightnessctl —
// one of the few places where the desktop shells out, and it is listed in the
// package notes for exactly that reason.
//
// `available` is false on a desktop and in the VM (no backlight device at all),
// and the quick settings page leaves the row out rather than showing a slider
// that moves nothing.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int max: 0
    property int value: 0
    readonly property bool available: max > 0
    readonly property real fraction: available ? value / max : 0

    // ⚠️ `-c backlight` is not optional. Without a class, brightnessctl picks
    // the FIRST device it finds — on the test VM that is `input1::numlock`, the
    // keyboard's numlock LED, class `leds`, max 1. The service then reported a
    // working backlight, the quick settings page drew a brightness slider, and
    // dragging it would have toggled a keyboard light. Measured, not imagined.
    function set(f) {
        if (!available) return
        var pct = Math.round(Math.max(0.01, Math.min(1, f)) * 100)
        apply.command = ["brightnessctl", "-c", "backlight", "-q", "set", pct + "%"]
        apply.running = true
        // Optimistic: the readback takes a moment and a slider that lags
        // behind the finger feels broken.
        root.value = Math.round(root.max * f)
    }

    Process { id: apply }

    Process {
        id: probe
        command: ["brightnessctl", "-c", "backlight", "-m", "info"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // machine-readable: device,class,current,percent,max
                // No backlight device means brightnessctl prints nothing and
                // exits with an error — exactly the answer we want: `max`
                // stays 0 and `available` is false.
                var parts = text.trim().split(",")
                if (parts.length >= 5 && parts[1] === "backlight") {
                    root._device = parts[0]
                    root.value = parseInt(parts[2]) || 0
                    root.max = parseInt(parts[4]) || 0
                } else {
                    root._device = ""
                    root.max = 0
                }
            }
        }
    }

    // ⚠️ THERE IS NO POLL TIMER HERE, and that is deliberate.
    //
    // There was one: every four seconds, forever, it ran `brightnessctl` — a
    // process spawn, 21 600 of them a day, to re-read a number that changes
    // when somebody presses a key. On the laptop this is built for that is
    // battery and heat spent on nothing, and "the shell does nothing while
    // nothing is happening" is the standard the whole project is held to.
    //
    // Instead the value is read when there is a reason to believe it changed:
    //
    //   * we changed it        — `set()` knows the new value already
    //   * a key changed it     — the binding runs brightnessctl and THEN tells
    //                            the shell, which calls refresh() (see
    //                            config/Config.qml; that order also means the
    //                            screen still brightens when the shell is dead)
    //   * the file changed     — the watch below, where the kernel offers one
    //
    // `sysfs` does not reliably deliver inotify events for attribute writes, so
    // the watch is a bonus rather than the mechanism. refresh() is the contract.
    function refresh() {
        if (root._device.length)
            level.reload()
        else
            probe.running = true
    }

    property string _device: ""

    FileView {
        id: level
        path: root._device.length
              ? "/sys/class/backlight/" + root._device + "/brightness" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var v = parseInt(text().trim())
            if (!isNaN(v)) root.value = v
        }
    }
}
