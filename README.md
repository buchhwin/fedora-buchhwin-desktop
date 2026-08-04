# buchhwin desktop

A one-command installer that turns a bare **Fedora Server 44** into a
**niri** desktop with a shell written entirely in **Quickshell/QML** —
a notch, a bar, a control centre, a launcher, a lock screen and a settings
window, all drawn from a single set of design tokens.

> **Status: pre-alpha.** Nothing here is ready to install yet.

## What makes it different

**One palette, one renderer, everything follows.** A colour scheme is 26
semantic names in a JSON file. `Theme.qml` derives every colour, radius,
spacing step, duration and font from it, and the same tokens are written out
to GTK 3, GTK 4/libadwaita, Qt, kitty, niri and the greeter. Changing the
palette repaints the desktop *and* the applications, with no second source of
truth and no template engine.

**One language above the installer.** The installer is bash, because it runs
on a machine with no desktop. Everything else — the shell, the theming, the
config generation, the tooling — is QML. No Python, no Lua, no GTK.

**Wayland-native, as far as the world allows.** Applications are configured
to run on Wayland rather than XWayland, and `bhctl doctor` lists any window
that still falls back, so the claim stays measurable instead of aspirational.

## Layout

    shell/          the Quickshell shell — the whole user interface
      theme/        Scheme.qml (palette) + Theme.qml (tokens) + palettes/
      config/       Config.qml — ~/.config/buchhwin/shell.json, one writer
      tools/        headless tools, run through the same import graph
      ui/           bar, notch, launcher, dock, settings
    lib/            installer phases (bash)
    packages/       package lists
    sddm/           the greeter theme, generated from the same tokens

## Licence

MIT. See `docs/CREDITS.md` for the projects this borrows ideas or code from.
