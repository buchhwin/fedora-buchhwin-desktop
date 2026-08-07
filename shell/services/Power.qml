pragma Singleton

// Battery, or the honest absence of one.
//
// `available` is false on a desktop, in a VM, and on any machine UPower does
// not know about — and the bar draws nothing rather than a battery symbol
// showing a number it invented. The test VM has zero UPower devices, so this
// service spends most of its life in exactly that state; that is the case
// worth getting right first, not an edge case.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../config"

Singleton {
    id: root

    readonly property var device: UPower.displayDevice

    readonly property bool available:
        device !== null && device.ready && device.isPresent && device.isLaptopBattery

    readonly property real percent: available ? device.percentage * 100 : 0
    readonly property bool charging:
        available && (device.state === UPowerDeviceState.Charging
                      || device.state === UPowerDeviceState.FullyCharged)

    // Seconds, or 0 when UPower has not worked it out yet — which it often has
    // not for the first minute after a state change.
    readonly property real secondsLeft:
        !available ? 0 : (charging ? device.timeToFull : device.timeToEmpty)

    // ⚠️ 15 AND 5 WERE HARD-CODED HERE while docs/CHECKLIST.md named the same
    // two numbers as the thresholds — so the documentation and the code agreed
    // by luck rather than by reading. They are settings now, and this is their
    // reader.
    readonly property int warnAt: Config.power ? Config.power.warnAt : 15
    readonly property int criticalAt: Config.power ? Config.power.criticalAt : 5

    readonly property bool low: available && !charging && percent <= warnAt
    readonly property bool critical: available && !charging && percent <= criticalAt

    // ------------------------------------------------------------- the warning
    // ⚠️ ONCE PER THRESHOLD PER DISCHARGE. UPower reports a new percentage every
    // few seconds, so "notify while below 15" is a notification every few
    // seconds — noise that trains you to ignore the one at 5. The flags latch on
    // the way down and are cleared by plugging in, which is the only event that
    // means "this discharge is over".
    //
    // ⚠️ AND THEY ARE CLEARED ON `charging`, NOT ON RISING PERCENTAGE. A battery
    // reading that wobbles 14 → 16 → 14 would otherwise re-arm and warn twice
    // for one crossing.
    property bool _warned: false
    property bool _warnedCritical: false

    onChargingChanged: {
        if (charging) {
            root._warned = false
            root._warnedCritical = false
        }
    }

    Process { id: announce }

    function _say(urgency, icon, title, body) {
        announce.command = ["notify-send", "--urgency=" + urgency,
                            "--app-name=buchhwin", "--icon=" + icon,
                            title, body]
        announce.running = true
    }

    function _remaining() {
        // UPower says 0 until it has an estimate, and "0 minutes left" on a
        // battery that has hours in it is worse than saying nothing.
        if (root.secondsLeft <= 0)
            return ""
        var m = Math.round(root.secondsLeft / 60)
        if (m < 60)
            return " — about " + m + " min left"
        return " — about " + Math.floor(m / 60) + " h " + (m % 60) + " min left"
    }

    onLowChanged: {
        if (!low || _warned)
            return
        root._warned = true
        root._say("normal", "battery-caution", "Battery low",
                  Math.round(root.percent) + "%" + root._remaining())
    }

    onCriticalChanged: {
        if (!critical || _warnedCritical)
            return
        root._warnedCritical = true
        // ⚠️ Also latches the low flag. Coming back from a suspend below 5 %
        // would otherwise cross 15 % on the way to the charger and warn about
        // "low" after having warned about "critical", in that order.
        root._warned = true
        root._say("critical", "battery-empty", "Battery critically low",
                  Math.round(root.percent) + "%" + root._remaining()
                  + ". Plug in now.")
    }
}
