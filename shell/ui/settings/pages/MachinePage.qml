// This machine — the graphics card, what the session does, and where it is.
//
// The leftovers of the old System page, and they belong together: all three are
// things about this particular computer rather than about the desktop.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    // ⚠️ THE GPU LIST WAS EMPTY UNLESS YOU HAD VISITED ANOTHER PAGE FIRST.
    // `renderChoices` below reads Services.Installed, and Installed scans only
    // when asked — KeyboardPage and TypePage both ask, this page never did. So
    // "Render on" offered one entry ("niri chooses") on a fresh window and the
    // full list after a detour through Keyboard, which reads as a list that
    // sometimes works. Found while adding the update rows, not by a check.
    //
    // Update.probe() is here rather than in the service for the same reason it
    // is in Installed: nothing asks the machine anything until a page that
    // shows the answer is open.
    Component.onCompleted: {
        Services.Installed.scan()
        Services.Update.probe()
    }

    readonly property var renderChoices: {
        var out = [{ value: "", label: "niri chooses" }]
        var d = Services.Installed.renderDevices
        for (var i = 0; i < d.length; i++)
            out.push({ value: d[i].path, label: d[i].driver ? d[i].driver : d[i].path })
        return out
    }

    // ------------------------------------------------------------------ updates
    //
    // ⚠️ ActionRows, not SettingRows: none of these three holds a value, and
    // giving them a `key` would mean punching an exception into
    // tests/setting-rows.sh. See the note at the top of ActionRow.qml.
    SettingGroup {
        Layout.fillWidth: true
        title: "Updates"

        // A statement, not an action — the one row in the window with no
        // button. What you want to know before pressing anything is which tree
        // you are running and how old it is.
        ActionRow {
            Layout.fillWidth: true
            label: "This desktop"
            hint: Services.Update.subject.length > 0
                      ? Services.Update.subject
                      : Services.Update.repoDir
            status: Services.Update.statusLine
            failed: Services.Update._probed && !Services.Update.isCheckout
        }

        // ⚠️ THIS ONE IS ALLOWED TO RUN IN THE WINDOW. `git fetch` needs no
        // root and changes nothing in the working tree — it only teaches the
        // local repository what the remote has. The button below is the one
        // that needs a terminal.
        ActionRow {
            Layout.fillWidth: true
            label: "Check for updates"
            hint: "Asks the remote what it has. It reads only — nothing here changes, and it needs no password."
            button: Services.Update.busy ? "Checking…" : "Check"
            usable: Services.Update.isCheckout && !Services.Update.busy
            failed: Services.Update.error.length > 0
            status: {
                if (Services.Update.error.length > 0)
                    return Services.Update.error
                if (!Services.Update.checked)
                    return ""
                var n = Services.Update.newCommits.length
                if (n === 0)
                    return "Already current."
                return n + (n === 1 ? " new commit:\n" : " new commits:\n")
                       + Services.Update.newCommits.join("\n")
            }
            onTriggered: Services.Update.check()
        }

        // ⚠️ A TERMINAL, AND IT IS THE POINT RATHER THAN A SHORTCUT. bhctl
        // update runs install.sh, install.sh runs dnf, and dnf asks for a
        // password. A button that silently waits on a prompt nobody can see is
        // a button that hangs — in a terminal you see the question and the
        // output, and you can answer it.
        ActionRow {
            Layout.fillWidth: true
            label: "Install the update"
            hint: "Opens a terminal running bhctl update: pull, then the installer. It is a terminal because the installer asks for your password."
            button: "Open a terminal"
            usable: Services.Update.canInstall
            failed: Services.Update.isCheckout && Services.Update.dirtyFiles > 0
            status: {
                if (!Services.Update._probed)
                    return ""
                if (!Services.Update.isCheckout)
                    return "Not possible here — this tree has no git history to pull into. That is normal on a machine the files were copied to."
                if (Services.Update.dirtyFiles > 0)
                    return "There are uncommitted changes in " + Services.Update.repoDir
                           + " — bhctl refuses to pull over them, and so does this button."
                return ""
            }
            onTriggered: Services.Update.install()
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Graphics"

        // ⚠️ A CLOSED LIST, NOT A FIELD WITH SUGGESTIONS — and it is the one row
        // in the window where that is the right way round. `niri validate`
        // accepts a device path that does not exist (measured on 26.04, with a
        // control: an invented KEY in the same block is rejected, a missing
        // DEVICE is not), and a config naming a device niri cannot open means
        // niri does not start. Everywhere else a typed value that this machine
        // does not have is merely wrong; here it costs the session, and a
        // "Not installed here" caption under a text box would be a warning
        // shown after the damage was already typed.
        //
        // ⚠️ AND IT IS NOT GATED ON THE NVIDIA MODULE, which was the first
        // idea and is worse: renderDevice is not an NVIDIA setting. Naming the
        // integrated card is legitimate, and a machine with two AMD GPUs has
        // the same question. The list itself is the guarantee — every entry is
        // a render node that exists here with a driver bound to it.
        //
        // The way out, if it is ever reached by editing shell.json by hand: a
        // TTY, clear gpu.renderDevice, `bhctl niri apply`. Also in docs/NIRI.md.
        SettingRow {
            Layout.fillWidth: true
            key: "gpu.renderDevice"
            label: "Render on"
            hint: "Which GPU niri draws with. On a hybrid laptop the external display sockets usually belong to the second card, so niri renders on the built-in one and copies each frame across for that screen — naming the second card here removes the copy, and costs battery, because that card then never idles."
            kind: "choice"
            choices: root.renderChoices
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Session"

        SettingRow {
            Layout.fillWidth: true
            key: "autostart"
            label: "Start with the session"
            hint: "Started with the session. The polkit agent is here by default — without it, anything that asks for a password gets no dialogue. A full path works too; these run through a shell."
            kind: "picks"
            options: Services.Suggest.allPrograms
            placeholder: "Nothing"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "workspaces"
            label: "Named workspaces"
            kind: "picks"
            options: Services.Suggest.workspaceNames
            placeholder: "None"
        }
        // ⚠️ THE LIMIT IS IN THE HINT, not only in the code. We can bring the
        // PROGRAMS back and not what was in them: Brave and VS Code restore
        // their own tabs, kitty does not, and nothing outside a program can
        // know what it had open. Promising "the same state" here would be a
        // promise broken on the first use.
        SettingRow {
            Layout.fillWidth: true
            key: "session.restore"
            label: "Open the same programs next time"
            hint: "The programs come back on the same screen, not what was inside them. The list is kept while you work, so it survives a machine that went down without asking."
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Where this machine is"

        // Its own group rather than a line in "Session", because it is used by
        // two different things — the weather and the light/dark schedule — and
        // neither of them owns it.
        SettingRow {
            Layout.fillWidth: true
            key: "location.name"
            label: "Place"
            hint: "Guessed from the timezone until you say otherwise. The quick panel has a search that fills all three."
            kind: "field"
            placeholder: "Guessed from the timezone"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "location.lat"
            label: "Latitude"
            kind: "field"
            placeholder: "unset"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "location.lon"
            label: "Longitude"
            kind: "field"
            placeholder: "unset"
        }
    }

    // ------------------------------------------------------- backup and reset
    //
    // ⚠️ THE WHOLE FILE, not one setting — which is why these are ActionRows and
    // not SettingRows. See the note at the top of ActionRow.qml for why a new
    // `kind` would have had to punch a hole in tests/setting-rows.sh.
    //
    // ⚠️ The path is fixed and printed rather than chosen. A folder picker
    // without GTK is still to be built (A4), and a button that opens nothing
    // would be worse than one that says where it put the file.
    SettingGroup {
        Layout.fillWidth: true
        title: "Backup and reset"

        ActionRow {
            Layout.fillWidth: true
            label: "Export settings"
            hint: "Writes a copy of shell.json to " + Backup.exportPath
            button: "Export"
            status: Backup.lastAction === "export" ? Backup.status : ""
            failed: Backup.failed
            onTriggered: Backup.exportSettings()
        }

        ActionRow {
            Layout.fillWidth: true
            label: "Import settings"
            hint: "Reads " + Backup.exportPath + " back in. An older export is migrated forward like any other file."
            button: "Import"
            status: Backup.lastAction === "import" ? Backup.status : ""
            failed: Backup.failed
            onTriggered: Backup.importSettings()
        }

        ActionRow {
            Layout.fillWidth: true
            label: "Reset everything"
            hint: "Back to the defaults. The file you have now is kept as shell.json.bak."
            button: "Reset"
            destructive: true
            status: Backup.lastAction === "reset" ? Backup.status : ""
            failed: Backup.failed
            onTriggered: Backup.resetSettings()
        }
    }
}
