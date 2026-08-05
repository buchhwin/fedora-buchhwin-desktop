pragma Singleton

// The player you are actually listening to, or the honest absence of one.
//
// MPRIS reports every player on the bus, including ones that are merely open.
// Picking "the first" gives you a browser tab that has been paused since
// Tuesday. So the choice is: a playing player wins; otherwise the last one that
// played; otherwise nothing at all — and `available` false means the media pill
// is not drawn, rather than drawn empty.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property var player: null
    readonly property bool available: player !== null

    readonly property string title: available ? player.trackTitle : ""
    readonly property string artist: available ? player.trackArtist : ""
    readonly property string artUrl: available ? player.trackArtUrl : ""
    readonly property bool playing: available && player.isPlaying
    readonly property bool canToggle: available && player.canTogglePlaying

    // "lulu. - Mrs. GREEN APPLE" — title first, then artist, as in the
    // reference screenshot.
    readonly property string label: {
        if (!available) return ""
        if (title.length && artist.length) return title + " - " + artist
        return title.length ? title : artist
    }

    readonly property bool canNext: available && player.canGoNext
    readonly property bool canPrevious: available && player.canGoPrevious

    function next() { if (root.canNext) root.player.next() }
    function previous() { if (root.canPrevious) root.player.previous() }

    function toggle() {
        if (!available || !player.canTogglePlaying) return
        if (player.isPlaying) player.pause()
        else player.play()
    }

    function pick() {
        var list = Mpris.players ? Mpris.players.values : null
        if (!list || !list.length) { root.player = null; return }
        var fallback = null
        for (var i = 0; i < list.length; i++) {
            var p = list[i]
            if (!p) continue
            if (p.isPlaying) { root.player = p; return }
            if (!fallback) fallback = p
        }
        // Keep the current one if it is still on the bus: a pause should not
        // make the pill jump to a different application.
        for (var j = 0; j < list.length; j++)
            if (list[j] === root.player) return
        root.player = fallback
    }

    Component.onCompleted: pick()

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.pick() }
    }

    // A player that starts playing takes over; one that stops hands back.
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onIsPlayingChanged() { root.pick() }
    }
}
