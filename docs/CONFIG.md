# shell.json — the one place settings live

`~/.config/buchhwin/shell.json`. Everything else is generated from it: niri's
`config.kdl`, the GTK/Qt/kitty themes, `environment.d`. There is no second
store and no intermediate format.

Every key has a default in `shell/config/Config.qml`. A missing file, a
truncated file or a key that does not exist yet all resolve to the same working
desktop — which is what makes it safe to add settings without a migration.

## Groups

| Group | What |
|---|---|
| `version` | migration marker; bumped only on a rename or removal |
| `theme` | `palette`, `accent`, `lightPalette` |
| `look` | `rounding`, `borderWidth`, `gapsIn/Out`, opacities, `blur`, `blurPasses`, `shadows`, fonts, `fontSize`, `profile` |
| `surfaces` | `notifications`, `osd`, `dock`, `wallpaper` — each on its own |
| `bar` / `notch` / `dock` | geometry, and a monitor list (empty = all) |
| `programs` | argument **lists**: `terminal`, `browser`, `fileManager`, `editor`, `imageViewer`, `video`, `launcher` |
| `keys` | `mod` plus `binds`: `{ key, action, arg, desc }` |
| `input` | `keyboard`, `touchpad`, `mouse`, `focusFollowsMouse`, `warpMouseToFocus` |
| `windows` | `noCsd`, `floating`, `blockFromScreencast` |
| `outputs` | per-monitor overrides; empty = let niri decide |
| `autostart` | extra programs — **not** the shell or the clipboard watcher |
| `workspaces` | named workspaces |
| `wallpaper` | `folder`, `current` image, `monitors` |

## The wallpaper, and what survives a restart

```json
"theme":     { "palette": "wallpaper", "accent": "blue" },
"wallpaper": { "folder": "/home/you/Bilder/Wallpaper",
               "current": "file:///home/you/Bilder/Wallpaper/Lake_Color1.png" }
```

**`wallpaper.current` is the only thing that is remembered**, and it is written
the moment you choose an image (`Super+Shift+W`, or `bhctl wallpaper <file>`).
Everything else is downstream of it:

- `theme.palette` set to **`"wallpaper"`** means the colour scheme is derived
  from that image. **There is no second switch** — a `wallpaper.derive` key
  existed until config version 1 and was removed, because two keys for one
  decision can disagree.
- The derived scheme is cached in `shell/theme/palettes/wallpaper.json`, an
  ordinary palette file with one extra field, `source`. On the next start the
  colours load from there instantly; the image is only read again when `source`
  no longer matches `wallpaper.current`. The file is generated, never committed.
- A wallpaper that cannot be decoded is **refused** and the previous scheme
  stays. An unreadable desktop is worse than one that did not change — and much
  worse if it comes back that way after every restart.
- Light or dark is yours, not the image's: a bright photo does not turn a dark
  desktop light. The image supplies hue, nothing else. **Meaning colours stay
  put** — error is red on a forest wallpaper too. An image with no colour in it
  yields a grey scheme rather than an invented one.

Wallpapers are **not** in this repository — they are photographs and this
repository is public. `install.sh --wallpapers <dir>` copies them to
`~/Bilder/Wallpaper`; without it the installer falls back to
`/usr/share/backgrounds`, and with no images anywhere it seeds Everforest Dark.

## Defaults worth knowing

**Only the notch is on.** `bar.enabled` is `false` and `surfaces.dock` is
`false`. The notch is the surface, not an ornament — so anything the bar would
have carried needs a key and an ipc verb as well, or it is unreachable.

**`look.profile: "minimal"`** is the one switch that turns the expensive things
off everywhere: `blur { off }`, no shadows, shorter motion. It is the first
thing to reach for on a slow machine, ahead of tuning individual effects.

**`look.blurPasses`** is the most expensive single number in the desktop —
every pass is another full-screen GPU read per frame.

## Programs are argument lists, not command lines

```json
"programs": { "terminal": ["kitty", "-e", "fish"] }
```

niri's `spawn` takes one string per argument. A single `"kitty -e fish"` makes
it look for a binary with spaces in its name. A binding refers to a program as
`"@terminal"`, so changing your terminal is one edit rather than a hunt through
the bindings. An **empty** list means the binding is dropped entirely — better
than a key that looks like a feature and does nothing.

## Migrations

`shell/config/Migrations.qml`. Adding a key needs nothing; renaming or removing
one needs a step, because the old name is already in somebody's file.

The chain runs on the **raw JSON**, deliberately: `JsonAdapter` drops every key
it does not declare, so by the time the adapter has parsed the file the old
field it exists to rescue is already gone. A config written by a *newer* build
is refused rather than downgraded by guesswork.

## Two traps in the QML

**`Array.isArray()` says `false`** for a list that came out of `JsonAdapter` —
it is a QJSValue wrapper, not a JS array. Use `.length` and indexing.

**`FileView.loaded` is not "the values are here".** It turns true one event-loop
step before the adapter applies them, so a one-shot read in the same tick
returns the defaults — silently. That deferral lives in `common/WaitFor.qml`;
wait on it rather than on `loaded`.
