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
| `theme` | `palette`, `accent`, `lightPalette`, `customColor` |
| `theming` | which programs we colour, and how — one state each, see below. `vscode` also sets `window.titleBarStyle: native`, which is what removes its title bar |
| `look` | `uiScale` (one number for the size of everything), `rounding`, `borderWidth`, `gapsIn/Out`, opacities, `blur`, `blurPasses`, `shadows`, fonts, `fontSize`, `profile` |
| `surfaces` | `notifications`, `osd`, `wallpaper` — each on its own |
| `notifications` | `dnd` (silences toasts, never critical ones), `timeoutMs`, `maxVisible`, `monitors` |
| `nightlight` | `on` and `temperature` in kelvin — 6500 is neutral, lower is warmer |
| `timer` | `presets` in minutes, `sound`, `soundFile` — the work timer on Mod+Shift+T |
| `bar` / `notch` / `launcher` | geometry, and a monitor list (empty = all) |
| `programs` | argument **lists**: `terminal`, `browser`, `fileManager`, `editor`, `imageViewer`, `video` |
| `keys` | `mod` plus `binds`: `{ key, action, arg, desc }` |
| `input` | `keyboard`, `touchpad`, `mouse`, `focusFollowsMouse`, `warpMouseToFocus` |
| `windows` | `noCsd`, `floating`, `blockFromScreencast` |
| `outputs` | per-monitor overrides; empty = let niri decide |
| `autostart` | extra programs — **not** the shell or the clipboard watcher |
| `workspaces` | named workspaces |
| `wallpaper` | `folder`, `current` image, `monitors` |
| `location` | `name` (display only), `lat`, `lon` — set from the quick panel |

## One state per program

```json
"theming": { "enabled": true, "mode": "colour", "kitty": "neutral", "qt": "off" }
```

`mode` is the house rule, and every program follows it unless it says otherwise.
The per-program keys are flat (`"kitty"`, not `"targets": {"kitty": …}`) — two
levels of `JsonObject` do not come back from the file, so the block would parse
and every switch would silently do nothing.

| State | What it means |
|---|---|
| `colour` | the system's colours, whatever `theme.palette` says |
| `neutral` | a grey scheme: themed, but colourless. **Colourless, not unstyled** — transparency, fonts and corners stay, and red, green and yellow stay coloured, because an error has to read as an error in a grey scheme too |
| `off` | we take our file back: it is left in place as a stub that overrides nothing, so the `include` that reads it does not point at nothing |
| `inherit` | follow `mode` — the default, so switching everything at once is one edit rather than twelve |

`enabled: false` is the master switch: every program behaves as `off`, files and
all. Setting it back to `true` fills them again — `off` is not a one-way door.

⚠️ **`off` for `gtk` is visible, and that is the point.** Theme name, icon theme,
font and `gtk-decoration-layout=:` all come out of the same generated file, so a
GTK window gets its three title-bar buttons back and turns light. That is what
"the way it would look without us" means here.

### What each program gets, and what points at it

| Key | Generated file | What names it |
|---|---|---|
| `gtk` | `gtk-3.0/gtk.css`, `gtk-4.0/gtk.css` + both `settings.ini` | nothing — GTK reads them itself |
| `qt` | `qt6ct/colors/buchhwin.conf` | `color_scheme_path` in `qt6ct.conf` |
| `kitty` | `kitty/theme.conf` | `include theme.conf` in `kitty.conf` |
| `niri` | `niri/colors.kdl` | `include optional=true` in the generated `config.kdl` |
| `btop` | `btop/themes/buchhwin.theme` (37 keys) | `color_theme = "buchhwin"` in `btop.conf` |
| `alacritty` | `alacritty/buchhwin.toml` | `[general] import` in `alacritty.toml` |
| `tmux` | `tmux/buchhwin.conf` | `source-file` in `tmux.conf` |
| `bat` | `bat/themes/buchhwin.tmTheme` | `--theme` in `bat/config` **plus `bat cache --build`** |
| `delta` | `git/buchhwin-delta.gitconfig` | `[include]` in `~/.config/git/config` |
| `lazygit` | `lazygit/buchhwin.yml` | `LG_CONFIG_FILE` in `environment.d` |

Every pointer is seeded once by the installer and never edited again. If one of
these files already exists without its pointer, the installer says so rather
than reaching into it — and `bhctl doctor` keeps saying so.

⚠️ **bat is the one with two steps.** A `.tmTheme` in the right folder is
invisible to bat until `bat cache --build` compiles it. The renderer runs that
itself, and only when the theme actually changed.

⚠️ **`delta` is written into `~/.config/git/config`, never into `~/.gitconfig`.**
Git reads both global files, so the include takes effect while a hand-written
`~/.gitconfig` stays exactly as it was.

**`fastfetch` and `starship` have no file of their own**, and that is not an
omission: neither program has any include mechanism — each reads a single
config file that belongs to you. Their colours come from the terminal's sixteen
ANSI colours, which the kitty and alacritty themes above already set, so they
follow the palette without us writing anything. The renderer says so on every
run.

**Only our own files are ever touched.** `kitty.conf`, `qt6ct.conf`, `btop.conf`
and `~/.gitconfig` belong to you; the pointer lines in them are seeded once by
the installer and never edited afterwards, not even by `off`.

## The launcher

```json
"launcher": { "enabled": true, "width": 720, "height": 460, "monitors": [] }
```

`Super+D` or `Super+Space`. Type to search, arrow keys to move, Enter to start,
Escape to close; Tab steps through the categories without leaving the keyboard.

⚠️ **It is the one surface that opens in the MIDDLE of the screen**, and the only
one that leaves the notch where it is — everything else opens at the notch, and
the notch steps aside for it. That is why it is not a notch page and has its own
ipc target: `qs -c buchhwin ipc call launcher toggle`.

A fixed size, unlike the notch pages: those are as big as their content because
their content is short, and a program list is not. A launcher that changes shape
while you type is a moving target.

**Where the list comes from.** Quickshell's `DesktopEntries` — the same
freedesktop database every desktop reads, so a newly installed program appears
without anything being rescanned. Three things are dropped or ignored, each of
them a fault the predecessor had: `NoDisplay=true` entries (they exist to own a
MIME type, not to be picked), `Actions` (one program is one row — listing them
turned Evolution into twenty lines), and everything in `Categories` that is not
a freedesktop **main** category, first match winning. `GTK`, `Qt`, `KDE` and
`X-*` are not categories, however often they appear in that field.

A program whose categories say nothing usable lands in **Other**, and a category
with nothing in it is never offered.

**Frequent** counts what you start from here, in
`~/.local/state/buchhwin/app-usage.json`. It is data rather than a setting, so
it is deliberately not in `shell.json` — and writing it there would mean
rewriting your whole configuration every time you started a program.

## The wallpaper, and what survives a restart

```json
"theme":     { "palette": "wallpaper", "accent": "blue" },
"wallpaper": { "folder": "~/Pictures/Wallpaper",
               "current": "file:///home/USER/Pictures/Wallpaper/Lake_Color1.png" }
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

**Only the notch is on.** `bar.enabled` is `false`, and there is no dock at all
yet. The notch is the surface, not an ornament — so anything the bar would have
carried needs a key and an ipc verb as well, or it is unreachable.

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

## The calendar, and Google

Appointments come from your Google account over CalDAV, using the account that
lives in `gnome-online-accounts` — the same one that puts Google Drive in
Nautilus. There is deliberately **no setting for it in `shell.json`**: the
account IS the setting.

```
gnome-online-accounts-gtk        # add the account, switch the calendar on
bhctl calendar                   # check that it arrived
```

`Super+C` shows the month. A dot under a day means something is on; the
appointments of the day you tap are listed under the grid. The **+** creates one
— on the day you are looking at, not on today.

**What is written here goes to Google, and therefore to your phone.** This is
real CalDAV, not a local scratch copy.

### Why not evolution-data-server

EDS is the usual route. It was measured and it cannot work from here: EDS ties
an opened calendar to the **calling D-Bus connection**, and since Quickshell
ships no DBus module the only door is `busctl` — where every invocation is a new
connection, so the object is gone before it can be queried
(`Object does not exist at path …`). Rescuing that would take a permanently
running helper in C, with a build step. GOA hands out a token in **one** short
call instead, and Google's CalDAV endpoint is already baked into GOA. The
difference is 32 packages and a build system.

### Limits, stated plainly

- **Time zones come from the `VTIMEZONE` inside the appointment**, not from the
  system. Quickshell's JS engine has **no `Intl`** — measured, `typeof Intl` is
  `undefined` — so there is no way to ask what offset a named zone had on a
  given day. Reading VTIMEZONE has the side benefit of not depending on this
  machine's zone database agreeing with Google's.
- **Recurrences** are expanded for `FREQ=DAILY|WEEKLY|MONTHLY|YEARLY` with
  `INTERVAL`, `COUNT`, `UNTIL` and `BYDAY`, plus `EXDATE` and moved instances.
  Anything more exotic (`BYSETPOS`, `BYWEEKNO`) is **not** expanded rather than
  half-guessed.
- No invitations, no attendees, no reminders, no attachments.
- **No offline queue.** With no network the page says so. Collecting changes to
  send later is the worse promise.


## The notch has three states

It used to BECOME each page. It does not any more — a calendar is not a notch
that got bigger. The pages float below it (`buchhwin-overlay`) and the notch
gets out of the way:

| State | When | What you see |
|---|---|---|
| full | resting | the pill with the clock |
| hidden | a page is open at the notch | nothing — the page has the stage |
| strip | the focused window is fullscreen | a hairline at the top; **hover it for the full notch** |

Two things had to be measured for this, and both are worth knowing:

- **niri does not report `is_fullscreen`.** The only signal is the size, and it
  arrives in the `WindowLayoutsChanged` event: a fullscreen window's
  `window_size` is exactly the output's logical size. The honest limit is that
  with `gaps 0` and no reserved strip an ordinary tiled window would measure the
  same — with the shipped defaults it cannot.
- **A fullscreen window is drawn above the `top` layer.** The strip was not
  mis-sized, it was simply not on screen. The notch moves to `overlay` while
  fullscreen and back afterwards, which is also why the strip is a hairline: it
  is the one thing allowed over a fullscreen video.

## Shadows, blur, and one rule that explains both

From niri's own layer-rule documentation:

> niri has no way of knowing about invisible margins, and will draw the shadow
> behind the **entire surface**.

Blur behaves the same. So **every surface this shell creates is exactly the size
of what it draws** — the notch used to carry a transparent border for its
shoulders, and that border came back as a blurred, colour-fringed halo around
the pill.

- `look.shadowSoftness` / `shadowSpread` / `shadowOffsetY` are CSS box-shadow
  semantics and apply to **windows and to our own surfaces alike**, so nothing
  floats at a different height from anything else.
- Layer surfaces need their shadow enabled **per rule** — the `layout` section
  does not reach them.
- `windows.blurred` lists the applications that get the wallpaper blurred behind
  them. ⚠️ Blur is only visible where a window is **translucent**; an opaque one
  covers it completely and the GPU work is wasted. niri turns on *xray*
  alongside blur, which blurs the wallpaper once and reuses it rather than
  recomputing per window per frame — that is what makes this affordable on a
  battery.
- **No blur behind the notch.** It is near-black and opaque: there was never
  anything to see through it.
