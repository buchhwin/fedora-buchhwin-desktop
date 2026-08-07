pragma Singleton

// What happens when the machine is left alone: the screen dims, then goes off,
// then the session locks, then it suspends.
//
// ⚠️ NONE OF THIS EXISTED, on a laptop. The desktop stayed awake and unlocked
// until the battery was flat. The last session concluded this needed technology
// that was not here — the handout said Quickshell has no idle service at all —
// and that was wrong on the first count. Quickshell 0.2.1 ships
// `IdleMonitor` in Quickshell.Wayland (re-exported from _IdleNotify), niri 26.04
// implements ext_idle_notifier_v1, and the lock screen has been in this repo
// since the beginning. Nothing was installed to make this work.
//
// ⚠️ `timeout` IS IN SECONDS, and that was measured rather than read: the type
// registration says "double" and stops there, while the Wayland protocol
// underneath counts milliseconds. shell/tools/idle-probe.qml asked for 3 against
// the real compositor and got `isIdle` at 3.00 s. Guessing that wrong is the
// difference between locking after five minutes and locking after three
// tenths of a second.
//
// ⚠️ FOUR INDEPENDENT MONITORS, NOT A CHAIN. Each delay counts from the start of
// idle, the way Windows counts: "screen off after 5, lock after 6" is two
// numbers a person can read back, not one number plus an offset that has to be
// re-derived whenever either moves. It also means a stage that is switched off
// cannot break the ones after it.
//
// ⚠️ AND EVERY MONITOR RESPECTS INHIBITORS. A video player holding an idle
// inhibitor stops all four, which is the entire reason the protocol has them.
// Without it this service is a thing that locks the screen during films.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "." as Services
import "../config"

Singleton {
    id: root

    // ⚠️ A MACHINE WITH NO BATTERY IS ON MAINS, not on battery. `available` is
    // false on a desktop and in a VM, and reading that as "on battery" would
    // give every desktop the aggressive timings.
    readonly property bool onBattery:
        Services.Power.available && !Services.Power.charging

    function _mins(v) {
        var n = Number(v)
        return (n > 0) ? Math.round(n * 60) : 0
    }
    function _pick(onBat, onAc) {
        // Config.power is null for the first frames of shell construction, like
        // every other group — see the guards elsewhere in this shell.
        if (!Config.power)
            return 0
        return root._mins(root.onBattery ? onBat : onAc)
    }

    readonly property int screenOffAfter: Config.power
        ? root._pick(Config.power.screenOffBattery, Config.power.screenOffAc) : 0
    readonly property int lockAfter: Config.power
        ? root._pick(Config.power.lockBattery, Config.power.lockAc) : 0
    readonly property int suspendAfter: Config.power
        ? root._pick(Config.power.suspendBattery, Config.power.suspendAc) : 0

    // Half a minute of warning before the screen goes, or a fifth of the delay
    // when the delay is short — a one-minute screen-off would otherwise dim
    // thirty seconds in, which is half the time spent dim.
    readonly property int dimAfter: {
        if (!Config.power || !Config.power.dimBeforeOff || root.screenOffAfter <= 0)
            return 0
        var lead = Math.min(30, Math.round(root.screenOffAfter * 0.2))
        return Math.max(1, root.screenOffAfter - lead)
    }

    // ------------------------------------------------------------------ dimming
    // ⚠️ THE LEVEL TO GO BACK TO IS REMEMBERED, NOT RECOMPUTED. Restoring to a
    // fixed number would silently overwrite whatever he had set; restoring to
    // "what it was" is the only version that is invisible when it works.
    property real _brightnessBefore: -1
    readonly property bool dimmed: root._brightnessBefore >= 0

    function dim() {
        if (root.dimmed || !Services.Brightness.available)
            return
        root._brightnessBefore = Services.Brightness.fraction
        Services.Brightness.set(Math.max(0.05, root._brightnessBefore * 0.3))
    }

    function undim() {
        if (!root.dimmed)
            return
        Services.Brightness.set(root._brightnessBefore)
        root._brightnessBefore = -1
    }

    // ------------------------------------------------------------------ actions
    Process {
        id: screenOff
        command: ["niri", "msg", "action", "power-off-monitors"]
    }
    Process {
        id: screenOn
        // ⚠️ Called explicitly rather than trusting the compositor to undo it.
        // niri's own wiki drives power-off-monitors from swayidle and says
        // nothing about what turns them back on, and "it probably wakes on
        // input" is not something to find out with a dark screen. Turning on a
        // monitor that is already on costs nothing.
        command: ["niri", "msg", "action", "power-on-monitors"]
    }

    // ⚠️ ONE LOCK SCREEN AT A TIME. It is a separate process that exits when it
    // unlocks, so `running` is exactly the question "is the screen locked by
    // us" — and starting a second one would leave two processes holding PAM
    // state for one screen.
    Process {
        id: locker
        command: ["sh", "-c", "BUCHHWIN_MODE=lock qs -c buchhwin"]
    }
    readonly property bool locked: locker.running

    function lock() {
        if (!locker.running)
            locker.running = true
    }

    Process {
        id: sleeper
        command: ["systemctl", "suspend"]
    }

    // ------------------------------------------------------- someone else asks
    // ⚠️ WITHOUT THIS, "lid closes → lock only" IS A SETTING THAT DOES NOTHING.
    // logind's `lock` action does not lock anything itself: it emits a `Lock`
    // signal on the session and expects the session's own software to carry it
    // out. Nothing in this shell listened, so the option would have been a
    // choice in a menu with no machinery behind it — the exact fault this repo
    // has found five times under "a key with no reader".
    //
    // It is not only the lid. `loginctl lock-session` is the standard way for
    // anything else on the system to lock the screen, and it was equally dead.
    //
    // ⚠️ Quickshell 0.2.1 has no generic D-Bus binding, so this is `gdbus
    // monitor` and a line match rather than a signal subscription. Matching on
    // ".Session.Lock" and not on "Lock" is deliberate: the same stream carries
    // Unlock, and a substring match would treat one as the other.
    Process {
        id: lockSignal
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                if (String(line).indexOf(".Session.Lock ") >= 0)
                    root.lock()
            }
        }
    }

    function suspend() {
        // ⚠️ LOCK FIRST. Suspending without locking means opening the lid gives
        // back an unlocked desktop, which turns the whole page into decoration.
        // The lock screen comes up before the machine goes down; it is still
        // there on resume, because it is a process and processes survive a
        // suspend.
        root.lock()
        sleeper.running = true
    }

    // ---------------------------------------------------------------- monitors
    IdleMonitor {
        enabled: root.dimAfter > 0
        timeout: root.dimAfter
        respectInhibitors: true
        onIsIdleChanged: isIdle ? root.dim() : root.undim()
    }

    IdleMonitor {
        enabled: root.screenOffAfter > 0
        timeout: root.screenOffAfter
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                screenOff.running = true
            } else {
                screenOn.running = true
                // Waking the screen also undoes the dim, even if the dim
                // monitor's own edge is late: what he sees on the way back must
                // be the brightness he left, not a dark screen that brightens a
                // moment later.
                root.undim()
            }
        }
    }

    IdleMonitor {
        enabled: root.lockAfter > 0
        timeout: root.lockAfter
        respectInhibitors: true
        onIsIdleChanged: { if (isIdle) root.lock() }
    }

    IdleMonitor {
        enabled: root.suspendAfter > 0
        timeout: root.suspendAfter
        respectInhibitors: true
        onIsIdleChanged: { if (isIdle) root.suspend() }
    }

    // ----------------------------------------------------------- power profile
    // ⚠️ tuned-ppd, NOT power-profiles-daemon. Both answer on
    // net.hadess.PowerProfiles; only tuned-ppd is installed here, and the two
    // collide if both are (the same way tlp and tuned do). The three names below
    // are what this machine actually offers, read off the bus rather than
    // assumed.
    //
    // polkit's allow_active is `yes` for switch-profile, so the shell may do
    // this without a prompt while its session is the active one. It is NOT
    // allowed from an inactive session — which is exactly what happens over SSH,
    // and is why this cannot be checked from the other end of the tunnel.
    Process {
        id: profileSet
        command: ["busctl", "set-property",
                  "org.freedesktop.UPower.PowerProfiles",
                  "/org/freedesktop/UPower/PowerProfiles",
                  "org.freedesktop.UPower.PowerProfiles",
                  "ActiveProfile", "s", root.profileWanted]
    }

    readonly property string profileWanted:
        Config.power ? String(Config.power.profile) : "balanced"

    onProfileWantedChanged: {
        if (root.profileWanted.length)
            profileSet.running = true
    }
    Component.onCompleted: {
        if (root.profileWanted.length && root.profileWanted !== "balanced")
            profileSet.running = true
    }
}
