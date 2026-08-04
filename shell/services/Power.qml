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
import Quickshell.Services.UPower

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

    readonly property bool low: available && !charging && percent <= 15
    readonly property bool critical: available && !charging && percent <= 5
}
