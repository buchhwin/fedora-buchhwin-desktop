// The lock screen. Its own process — see shell.qml for why that is a safety
// property and not a layout choice.
//
// ⚠️ WHAT HAPPENS IF THIS CRASHES. The ext-session-lock protocol says a
// compositor must keep the session locked behind a blank screen when the
// locking client disappears without unlocking. So a fault here leaves you at a
// blank locked screen and needing a TTY — inconvenient, and the correct
// direction to fail in. The opposite, a crash that unlocks, is what running
// this inside the shell would have risked.
//
// ⚠️ IT LOCKS ON STARTUP AND EXITS ON UNLOCK. There is no "hide" state. A lock
// screen that is running but not locking is a process that looks like security
// and is not.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"

Scope {
    id: root

    WlSessionLock {
        id: session

        // Locked the moment the process exists. Nothing waits for a signal,
        // because between "process started" and "signal handled" is a window
        // where the desktop is visible and unlocked.
        locked: true

        WlSessionLockSurface {
            // Behind the face, and drawn even before it: a lock surface that
            // starts transparent shows the desktop through it for as long as
            // the first frame takes.
            color: Theme.bgDeep

            LockFace {
                anchors.fill: parent
                onUnlocked: {
                    session.locked = false
                    // The process has one job and it is done. Staying alive
                    // would leave a second copy holding PAM state the next time
                    // the screen locks.
                    Qt.quit()
                }
            }
        }
    }
}
