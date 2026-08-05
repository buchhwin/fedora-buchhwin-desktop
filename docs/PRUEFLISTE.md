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
- [ ] Insel und Bar **sind** da (seit M3, siehe unten). Wenn du nur M2 prüfen
      willst: `bhctl shell reset` setzt auf die Vorgabe zurück — dann ist nur die
      Insel an, die Bar aus.

## 2. Tasten durchgehen

⚠️ **Nicht über VNC testen.** Über VNC injizierte Tasten erreichen niris Bindungen
nicht — gemessen: weder mit `Super`, noch mit `Alt`, nicht einmal ein blankes `F9`,
obwohl die Konfiguration geladen ist. Der Zeiger geht, die Tastatur nicht. Dazu
fangen viele VNC-Betrachter die Super-Taste schon auf deinem eigenen Rechner ab.
Wer so testet, hält funktionierende Kürzel für kaputt.

**Nimm die Proxmox-Konsole** (`https://192.168.2.84:8006` → VM 9002 → Console) — die
emulierte USB-Tastatur sieht niri als echtes Gerät. Oder ferngesteuert vom Host:

```
ssh-proxmox.sh "qm sendkey 9002 meta_l-ret"   # Super+Return
ssh-proxmox.sh "qm sendkey 9002 meta_l-e"     # Super+E
```

Auf diesem Weg bereits belegt: **Super+Return startet kitty, Super+E Nautilus,
Super+O öffnet die Übersicht.** Die restlichen Stichproben:

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

Mitteilungen, Starter, Dock, Einstellungsfenster, Sperr- und Anmeldebildschirm
(M5–M9) · Wallpaper-Auswahl mit abgeleitetem Farbschema (M3.5) ·
XWayland-Messung (M10). Bar und Insel stehen seit M3.

**SDDM ist noch installiert** und wird erst entfernt, wenn der eigene
greetd-Greeter nachweislich bis zum Desktop durchkommt — ein kaputter Greeter
hieße kein Login mehr.

---

# Prüfliste M3 — Shell, Bar und Insel

## Schon am Bildschirm belegt (VM, mit echten Screenshots)

| | |
|---|---|
| Bar und Insel sind **eine** Silhouette | Insel sitzt mittig in der Leiste, Schultern verschmolzen |
| Insel im Ruhezustand | nahezu schwarz, unten abgerundet, konkave Schultern, Uhr darin |
| Lautstärke verwandelt die Insel | Lautsprecher, gefüllte Spur, „80 %" — wie in deiner Vorlage |
| Strut reserviert exakt 34 px | gegen die Kachelhöhe nachgerechnet |
| Palettenwechsel wirkt live | `bhctl theme nord`, gleiche Prozess-ID |
| Uhr steht nur einmal | in der Bar, wenn sie an ist; sonst in der Insel |

## Was nur du prüfen kannst

- [ ] **Medien-Pille.** Auf der VM ist kein MPRIS-Spieler installiert, sie bleibt dort
      korrekt unsichtbar. Auf deinem Gerät: Spotify oder Discord starten — es müssen
      **Albumbild, Titel und ein Play/Pause-Knopf** erscheinen, sonst nichts.
      Gegenprobe: Spieler beenden → die Pille verschwindet, sie wird nicht leer.
- [ ] **Tray.** Auf der VM lief kein Tray-Programm. Prüfen: Symbol erscheint,
      Linksklick aktiviert, Rechtsklick öffnet das Menü.
- [ ] **Akku.** Die VM hat keinen. Auf dem Laptop: Prozentzahl stimmt, Symbol wechselt
      beim Anstecken, unter 15 % wird es gelb, unter 5 % rot.
- [ ] **Wie fühlt sich die Bewegung an?** Die VM hat eine Virtio-GPU — flüssig dort sagt
      nichts. Auf echter Hardware: klappt die Insel weich auf, ohne Nachfedern?
- [ ] **Blur hinter der Insel.** Die Layer-Regel steht in `config.kdl`, sichtbar wird sie
      erst mit einem Wallpaper dahinter.
- [ ] **Zwei Bildschirme.** Bekommt jeder Schirm seine eigene Silhouette?

## Bekannt und noch nicht gebaut

Notch-Seiten für Einstellungen, Medien und Mitteilungen (bisher nur Lautstärke) ·
Einstellungsfenster (M8, Vorlage aus deinem Screenshot liegt vor) · Starter · Dock ·
Sperr- und Anmeldebildschirm.

---

# Prüfliste M4 — die Insel als Seiten-Wirt

## Am Bildschirm belegt

| | |
|---|---|
| Lautstärke | Insel wird zum Regler, Lautsprecher · Spur · Prozent |
| Medien | Albumbild, Titel, Play/Pause — Leerzustand ist ein Satz Text |
| Mitteilungen | `notify-send` verwandelt die Insel, Eintrag mit Schließen-Knopf |
| Schnelleinstellungen | Lautstärkeregler; die Helligkeitszeile fehlt korrekt, weil die VM keinen Bildschirmregler hat |
| Öffnen und Schließen | Klick auf die Insel, Klick daneben, `ipc call notch …` |

## Was nur du prüfen kannst

- [ ] **Helligkeit** auf dem Laptop: Zeile erscheint, Ziehen ändert wirklich die
      Bildschirmhelligkeit. ⚠️ Ohne `-c backlight` griff `brightnessctl` auf der VM die
      **Numlock-LED** ab — auf deiner Hardware bitte gegenprüfen, dass es der Bildschirm ist.
- [ ] **Wie fühlen sich die Übergänge an?** Wächst die Insel weich in die Seite hinein,
      ohne Nachfedern? Die Virtio-GPU der VM sagt darüber nichts.
- [ ] **Größe der Insel** gegen deinen Screenshot halten — eingeklappt 150×34,
      ausgeklappt 135 hoch. Auf echter Hardware nachmessen.
- [ ] **Medien** mit Spotify oder Discord: Albumbild und Titel korrekt, Play/Pause wirkt.

---

# Prüfliste M3.5 — Hintergrundbild und das Schema daraus

## Am Bildschirm belegt (VM, echte Screenshots)

| | |
|---|---|
| Das Bild wird gezeichnet | eigene Fläche auf der `background`-Ebene |
| Auswahl als **Insel-Seite** | die Insel wächst zur Bilderreihe, kein zweites Fenster |
| Das aktive Bild ist markiert | Häkchen; der Rahmen ist der Tastatur-Zeiger |
| Das Schema folgt dem Bild | Desert1 → `#f5b648`, Lake3 → `#f88844` — die gemessenen Saattöne |
| Es folgt bis in fremde Programme | `gtk.css` steht auf demselben Wert |
| **Neustart** | echter Reboot: Bild **und** Schema stehen unverändert wieder da |
| Everforest ist nicht mehr Vorgabe | frische Installation sät `palette: "wallpaper"` |

## Was nur du prüfen kannst

- [ ] **`Super+Shift+W`** öffnet die Auswahl — über die Proxmox-Konsole, nicht über VNC.
- [ ] **Gefällt dir das abgeleitete Schema?** Alle zwölf Bilder durchgehen. Wenn eines
      unangenehm aussieht: sagen, welches und warum — die Ableitung hat Stellschrauben.
- [ ] **Die Übergänge:** wächst die Insel weich in die Bilderreihe, ohne Nachfedern?
- [ ] **Auf echter Hardware**: sieht das Bild bei HiDPI scharf aus, und wie lange dauert
      der Wechsel auf einem echten Laufwerk?

# Prüfliste M4-Rest — Kalender und Infobereich

## Am Bildschirm belegt

| | |
|---|---|
| Kalender | ganzer Monat, sechs Wochen, heute im Akzent, Wochentage stimmen |
| Die Insel wächst dafür | `expandedHeight` ist jetzt eine **Untergrenze**, wie die Breite |
| Tray | Seite öffnet, Leerzustand ist ein Satz Text |
| Alle sieben Seiten | über `ipc` und über Tasten erreichbar, keine Warnung im Log |

## Was nur du prüfen kannst

- [ ] **Tray mit einem echten Programm** (die VM hatte keines): Symbol erscheint,
      Linksklick aktiviert, **Rechtsklick öffnet das Menü — bei ausgeschalteter Bar**.
      Das ist der eigentliche Test, denn die Bar ist in der Vorgabe aus.
- [ ] **Kalender blättern** mit ‹ › und mit den Pfeiltasten, „heute" springt zurück.

---

# Prüfliste — Google-Kalender

**Das kann ich ohne dein Konto nicht prüfen.** Ich habe gegen feste Beispieldateien
getestet (23 Prüfungen, alle grün, ohne Netz); das Zusammenspiel mit Google prüfst du.
Zugangsdaten brauche ich dafür nicht — das Konto legst du an, das Token holt sich die
Shell zur Laufzeit aus den Online-Konten.

## Schon belegt (ohne Konto)

| | |
|---|---|
| Ohne Konto sagt die Seite das | „Kein Google-Konto mit eingeschaltetem Kalender" — ein Satz, kein leeres Raster |
| Das **+** ist dann nicht da | ein Knopf, der ein Formular öffnet das nicht speichern kann, wäre schlimmer als keiner |
| Anlege-Seite | Titel · Datum · Von–Bis · ganztägig; „Speichern" bleibt grau, solange etwas nicht stimmt |
| Zeitzonen | 14:00 Berlin = 12:00 UTC im August, 13:00 UTC im Januar — aus der `VTIMEZONE` |
| Serien | wöchentlich erscheint an **jedem** Termin, Ausfälle fehlen, verschobene Einzeltermine gewinnen |
| Monatsrechnung | Februar 2028 = 29, Februar 2100 = 28, Februar 2400 = 29 |

## Was du prüfen musst

1. [ ] `gnome-online-accounts-gtk` starten, **Google-Konto hinzufügen, Kalender
       einschalten**.
2. [ ] `bhctl calendar` → Konto, Token-Restlaufzeit, `HTTP 207` und „reachable".
       ⚠️ Das Token selbst wird bewusst **nicht** ausgegeben.
3. [ ] `Super+C`: stehen die Termine dieses Monats da? Gegen calendar.google.com halten.
4. [ ] Ein **wöchentlicher** Termin muss an jedem Termin erscheinen, nicht nur einmal.
5. [ ] Ein **ganztägiger** Termin muss auf seinem Tag stehen — nicht einen daneben.
6. [ ] Punkt unter den Tagen mit Terminen; Tag antippen → Liste darunter stimmt.
7. [ ] **Die Abnahme:** `Super+Shift+N`, Termin anlegen → **auf dem Handy nachsehen**.
8. [ ] Umgekehrt: Termin im Handy anlegen → Insel neu öffnen → er ist da.
9. [ ] Gegenprobe ohne Netz (`nmcli networking off`): eine Zeile Text, kein Hänger.

## Noch nicht gebaut

**Wetter** auf der Kalender-Seite — kommt in M8 zusammen mit der Ortssuche, weil ein
Wetterfeld ohne Eingabefeld für den Ort auf einem fremden Gerät nur hübsch lügt.

**Ändern und Löschen** von Terminen. Der Dienst kann es (`remove()` mit `If-Match`),
die Oberfläche dafür fehlt bewusst noch: ein falsches Löschen trifft einen echten
Termin, und dafür will ich erst, dass die Anzeige nachweislich stimmt — Punkte 3 bis 6
oben.
