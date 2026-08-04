# Prüfliste M2 — was nur du am Bildschirm feststellen kannst

Alles hier ist **gebaut und maschinell geprüft**, aber nicht mit Augen gesehen.
Die VM kann Richtigkeit prüfen, nicht Aussehen — und sie hat weder Ton noch
Akku noch echte Grafik.

Test-VM: **Proxmox 9002 `niri-m0`, 192.168.2.79**, Login `buchhwin`/`buchhwin`,
VNC `:5900`. Arbeitsstand liegt in `~/repo`.

---

## Bereits maschinell belegt (musst du nicht nachprüfen)

| | Beleg |
|---|---|
| `config.kdl` wird erzeugt und ist gültig | `tests/niri-config.sh`, 10 Fälle, Exit 0 |
| Einstellungen wirken wirklich | `gapsOut 24 → gaps 24`, `borderWidth 3 → border { on; width 3 }`, `profile minimal → blur { off }` |
| Zweiter Lauf schreibt nichts | `0 written, 2 unchanged` |
| Frische Maschine ohne `shell.json` | erzeugt gültige Vorgaben |
| Farben getrennt von Struktur | `colors.kdl` hat nur Farben, `config.kdl` behält `border { off }` |
| Alle 11 Paletten laden echt | `tests/all-palettes.sh`, 60 unterschiedliche Zeilen je Palettenpaar |
| Kaputte Paletten fallen durch | fehlender Schlüssel, kaputtes JSON, `bg == fg` — alle drei FAIL |

---

## 1. Anmelden und schauen (das Wichtigste)

```
ssh buchhwin@192.168.2.79
cd ~/repo && bash install.sh      # oder nur: bhctl niri apply
```

- [ ] **niri startet und kein waybar ist zu sehen.** Falls doch eine fremde
      Leiste erscheint: `rpm -q waybar` — dann wurde mit Empfehlungen installiert.
- [ ] `niri msg -j windows` liefert Fenster, kein Xwayland-Prozess (`pgrep Xwayland`)
- [ ] Die Notch ist **nicht** da und die Bar auch nicht — beides ist in M2 noch
      nicht gebaut. Erwartet ist ein **leerer, funktionierender** Desktop.

## 2. Tasten durchgehen

Die vollständige Liste steht in `docs/NIRI.md`. Stichproben, die wirklich zählen:

- [ ] `Super+Return` öffnet kitty
- [ ] `Super+E` öffnet Nautilus, `Super+B` den Browser
- [ ] `Super+←/→` bewegt den **Fokus**, `Super+Shift+←/→` das **Fenster**
- [ ] `Super+Ctrl+←/→` macht die Spalte schmaler/breiter (war beim Vorgänger Snap)
- [ ] `Super+Ö` springt auf die Ablage, `Super+Shift+Ö` schiebt ein Fenster dorthin
- [ ] `Super+1…9` wechselt Arbeitsflächen
- [ ] `Print` macht einen Screenshot
- [ ] `Super+Shift+Slash` zeigt die Tastenübersicht — **hier siehst du auf einen
      Blick, ob alle Beschriftungen stimmen**
- [ ] ⚠️ **Rettungstasten**: Shell absichtlich stoppen
      (`systemctl --user stop buchhwin-shell`), dann muss `Super+Shift+Return`
      trotzdem ein Terminal öffnen und `Super+Ctrl+Shift+R` den Shell neu starten

## 3. Keine Fensterknöpfe — an echten Fenstern

Je ein Fenster öffnen und **oben rechts** schauen: Minimieren/Maximieren/Schließen
müssen weg sein, die Kopfleiste selbst bleibt (das ist so gewollt, siehe NIRI.md).

- [ ] Nautilus (GTK4/libadwaita) — sollte aussehen wie dein Screenshot
- [ ] kitty
- [ ] ein Qt-Fenster (z. B. `vlc`)
- [ ] VS Code und Brave (Electron — die sind erfahrungsgemäß am störrischsten)

Was nicht klappt: **notieren, nicht wegdiskutieren.** Der Electron-Teil ist
ausdrücklich erst für M10 gemessen.

## 4. Nautilus, Netzlaufwerke, Google Drive

- [ ] `gnome-online-accounts-gtk` starten und **ein Google-Konto wirklich
      hinzufügen**. ⚠️ Das Paket steht auf 3.50.10, GOA selbst auf 3.58 —
      dieser Versionsversatz ist der Grund, warum ich es nicht behaupte.
- [ ] Danach: taucht Google Drive in Nautilus in der Seitenleiste auf?
- [ ] Ein SMB-Ziel verbinden (`Andere Orte` → `smb://…`)
- [ ] Gegenprobe für Nicht-GTK-Programme: liegt der Mount unter
      `/run/user/1000/gvfs/` und kann `ls` ihn sehen? (dafür ist `gvfs-fuse` da)
- [ ] **Datei-öffnen-Dialog in einem beliebigen Programm** — er sollte der
      Nautilus-Dialog sein. Das ist der Grund, warum Nautilus gesetzt ist.

## 5. Wenn etwas schiefgeht

```
bhctl doctor                       Versionen, Unit, Konfig, XWayland, Startzeit
bhctl niri diff                    was würde eine Neuerzeugung ändern
niri validate -c ~/.config/niri/config.kdl
cat /tmp/buchhwin-niri.log         Bericht des Erzeugers
cat /tmp/buchhwin-render.log       Bericht des Theme-Renderers
```

Eine kaputte `config.kdl` ist kein Drama: die Tasten stehen im Compositor, und
`bhctl niri apply` sagt es dir mit Exit 1 statt still zu scheitern.

---

## Offen aus früheren Meilensteinen (nicht M2, aber noch ungesehen)

- [ ] Ob die vier Test-Addons-Entscheidungen noch stimmen
- [ ] niri #2519 (Ziehen aus einem GTK4-Popover) — in M0 **nicht reproduziert,
      aber auch nicht widerlegt**

## Bewusst noch nicht gebaut

Bar, Notch, Mitteilungen, Starter, Dock, Einstellungsfenster, Sperr- und
Anmeldebildschirm (M3–M9) · Wallpaper-Auswahl mit abgeleitetem Farbschema
(M3.5) · XWayland-Messung (M10).

**SDDM ist noch installiert** und wird erst entfernt, wenn der eigene
greetd-Greeter nachweislich bis zum Desktop durchkommt — ein kaputter Greeter
hieße kein Login mehr.
