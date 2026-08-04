# The generated niri configuration

`~/.config/niri/config.kdl` is **generated**. Editing it edits a file that is
overwritten the next time a setting changes. The source is
`~/.config/buchhwin/shell.json`; the generator is `shell/tools/niri.qml`.

```
~/.config/buchhwin/shell.json     you edit this
        │
        ├── tools/niri.qml   ──▶  ~/.config/niri/config.kdl
        │                    ──▶  ~/.config/environment.d/50-buchhwin.conf
        └── tools/render.qml ──▶  ~/.config/niri/colors.kdl   (colours only)
                             ──▶  gtk-3.0, gtk-4.0, kitty, qt6ct
```

Regenerate with `bhctl niri apply`. See what would change with `bhctl niri diff`.

## Why two files

`config.kdl` includes `colors.kdl`, so switching palette rewrites the colours
and leaves the keybindings untouched. Three rules make that split work, all
taken from niri's own documentation:

* `include` is **top level only** and **positional** — what comes *after* an
  include overrides it. The include therefore sits after our `layout` block.
* Sections **merge property by property**, so a colours file that sets only
  `border { active-color … }` does not disturb `gaps` or `width`.
* ⚠️ `layout { border {} }` means "enable the border" in the main config and
  **nothing at all** in an included file. Visibility (`on`/`off`/`width`) is
  therefore written **only** into `config.kdl`, and `colors.kdl` carries
  colours and nothing else.

## What is deliberately not generated

**No `spawn-at-startup` for our own shell.** The shell and the clipboard
watcher are systemd user units under `graphical-session.target`. Listing them
here as well would start a second copy of each — which is exactly what Fedora's
shipped niri config does with waybar.

**No colours.** See above.

## Environment variables are written twice, on purpose

niri's `environment {}` block does **not** reach the systemd and D-Bus
activation environment. Our shell runs as a systemd user unit, and every
program launched from it is its child — so a variable set only in `config.kdl`
would never reach them. The same list is therefore also written to
`~/.config/environment.d/50-buchhwin.conf`, which the systemd user manager
reads at login.

⚠️ `GDK_BACKEND` is deliberately **not** among them. From niri's documentation:
*"Do not set the `GDK_BACKEND` environment variable globally as this will break
the screencast portal."* GTK applications choose Wayland by themselves here.

## No window buttons — what that does and does not mean

| Toolkit | How |
|---|---|
| niri | `prefer-no-csd`, `border { off }`, `focus-ring { off }` |
| GTK 3 / GTK 4 / libadwaita | `gtk-decoration-layout=:` in the generated `settings.ini` |
| Qt | `QT_WAYLAND_DISABLE_WINDOWDECORATION=1` |
| Electron | `--ozone-platform=wayland` flags in `~/.config/*-flags.conf` |

**The header bar itself stays.** In a libadwaita application the header bar is
application *content*, not decoration: minimise, maximise and close disappear,
while search fields and path bars remain. No setting removes it, and pretending
otherwise would be a promise the desktop cannot keep.

## Keys

Every binding is generated from `keys.binds` in `shell.json`. They live in the
compositor rather than in the shell because niri has no protocol for
shell-owned shortcuts — which also means **they keep working when the shell is
dead**. Two are reserved for exactly that case:

| Key | Action |
|---|---|
| `Super+Shift+Return` | terminal |
| `Super+Ctrl+Shift+R` | restart the shell unit |

### Changed compared with the Hyprland predecessor

niri is scrolling column tiling. Four groups of keys had no equivalent and were
remapped to the nearest real meaning rather than silently dropped:

| Key | Was (Hyprland) | Now (niri) |
|---|---|---|
| `Super+Ctrl+←/→` | snap to left/right half | column narrower / wider (±10 %) |
| `Super+Ctrl+↑` | snap maximise | `maximize-column` |
| `Super+Ctrl+↓` | snap restore | cycle preset column widths |
| `Super+Shift+J/K` | toggle split direction | consume / expel window from column |
| `Super+P` | pin window | toggle floating |
| `Super+Ö` | scratchpad | focus the named workspace `scratch` |

Also different from the predecessor: `Super+arrow` moves **focus** and
`Super+Shift+arrow` moves the **window**, following niri's own convention.

**Minimising does not exist** in niri. Workspaces and the overview replace it.

### Keys that are not bound yet

`programs.launcher` is empty, so the launcher key is **not** generated. A
binding that points at a program which does not exist would look like a
feature and do nothing; the generator drops it instead. It appears
automatically once M6 provides a launcher.

## Traps that cost a debugging round

* **`spawn` takes one string per argument.** `spawn "kitty -e fish"` makes niri
  look for a binary with spaces in its name. Commands are argument *lists*
  everywhere in `shell.json`.
* **On the top level the node is `spawn-sh-at-startup`**, not `spawn-sh` —
  `spawn-sh` is a bind action. The wrong one is rejected outright, and a config
  that does not parse means a desktop with **no keys at all**.
* **libinput flags reject `false`.** `natural-scroll false` is a hard error,
  unlike most other niri flags. The generator omits a flag rather than writing
  it false.
* **KDL needs a terminator.** `layout { gaps 16 }` on one line fails; anything
  inline gets a `;`.
* **`binds {}` is not defaulted.** Leave it out and the desktop has zero
  keybindings — and `niri validate` still says the config is valid.
* **`niri validate` exits 0 on warnings.** Deprecated keys and out-of-range
  values pass silently, which is why `tests/niri-config.sh` also greps stderr.
* **niri writes its own default config if none exists** — the one that starts
  waybar. The installer must generate ours before the first login.
