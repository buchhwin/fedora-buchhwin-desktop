pragma Singleton

// The default sink, or the honest absence of one.
//
// The test VM has no audio hardware at all — Pipewire reports zero nodes — so
// `available` false is the normal state there, not a fault. A bar that renders
// a volume symbol on a machine with no sound card is lying.
//
// PwObjectTracker is required: without it the node's volume and mute stay
// unbound, and the value read is whatever it was when the object appeared.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: Pipewire.ready && sink !== null && sink.ready

    readonly property real volume: available && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: available && sink.audio ? sink.audio.muted : true

    function setVolume(v) {
        if (!available || !sink.audio) return
        sink.audio.volume = Math.max(0, Math.min(1, v))
    }
    function toggleMute() {
        if (!available || !sink.audio) return
        sink.audio.muted = !sink.audio.muted
    }

    // Binds the node so its properties actually track. Leaving this out is the
    // classic Pipewire mistake: everything reads as a frozen snapshot.
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
}
