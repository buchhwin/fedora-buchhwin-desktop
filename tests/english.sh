#!/usr/bin/env bash
#
# The second tripwire.
#
# This desktop was written in German and is published in English, and that is
# not a one-off translation but a boundary that decays: the next label typed in
# a hurry is German, because the person typing it thinks in German. It happened
# once already — ~90 visible strings, 55 keybinding descriptions that land in
# niri's own shortcut overlay, and a whole checklist, all in a public
# repository whose own plan says English.
#
# So it is checked rather than remembered, in the same shape as
# tests/no-literals.sh: a line that genuinely needs an exception says so.
#
#     property string key: "Super+Ö"    // english-ok: the name of a physical key
#
# ⚠️ IT LOOKS FOR GERMAN FUNCTION WORDS, NOT FOR UMLAUTS.
#
# Umlauts alone are the wrong test twice over: half of German has none
# ("Fokus nach links"), and the ones that survive on purpose are key names on a
# German keyboard. Function words are what a sentence cannot avoid, and they do
# not collide with English — which is why `die`, `was`, `man`, `mit` and `so`
# are deliberately NOT in the list below, however German they look: this
# repository contains a shell function called `die`, the MIT licence, and a
# great many English sentences. `Taste` came out for the same reason on the
# tripwire's very first run — "a matter of taste" is not German.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

fail=0
report() { printf '  \033[38;5;203m%s\033[0m  %s\n' "$1" "$2"; fail=1; }

words='der|das|dass|und|oder|nicht|kein|keine|keinen|wird|wurde|werden|sind'
words+='|eine|einen|einem|eines|von|für|fuer|auf|aus|nach|noch|schon|wenn|dann'
words+='|alle|alles|muss|kann|soll|sollen|warum|ich|sich|mehr|immer|nie|sehr'
words+='|wie|wo|zum|zur|vom|beim|durch|ohne|gegen|über|ueber|unter|zwischen'
words+='|jeder|jede|jedes|dieser|diese|dieses|diesem|damit|weil|aber|auch|nur'
words+='|schliessen|schließen|öffnen|oeffnen|Fenster|Farbe|Datei|Ordner'
# Added after one slipped through: "Einstellungen kommen in M8 — bis dahin
# shell.json" contains not one word from the list above. A word list is only
# ever as good as its last miss, so a miss earns an entry rather than a shrug.
words+='|Einstellung|Einstellungen|kommen|kommt|bis|dahin|bisher|jetzt|heute'
# ⚠️ `Programme` CAME BACK OUT, on the rule this file already states about
# `die`, `was`, `man` and `Taste`: a word that is also correct English does not
# belong in the list. "programme" is the British spelling this repository writes
# elsewhere ("colour", "behaviour"), and forbidding it turns the tripwire into a
# trap for somebody writing correct prose. `Programm` alone has no English
# collision and stays — \b sees the trailing "e" as part of the word, so it does
# not match the English one.
words+='|Programm|Taste[nr]|Starter|Leiste|Suche|Sitzung|Bildschirm'
# Two more that slipped through into the location picker and shipped: a button
# labelled "stimmt" and a status reading "sucht …". Neither contains a word from
# the lists above, and neither is a function word — which is the limit of the
# method, not a reason to stop extending it.
words+='|stimmt|stimmen|sucht|suchen|gefunden|Ton|Netz|Gerät|Geraet|Geräte|Geraete'
# ⚠️ AND THEN A WHOLE WEATHER FORECAST WAS FOUND IN GERMAN — nine of the ten
# descriptions the panel shows, plus two calendar errors, a location error and
# the town-name placeholder. Not one of them contains a function word, which is
# the honest limit of the method: it catches sentences, and a label is not a
# sentence. Nouns a user-facing string is likely to be made of therefore go in
# too, even though each one is a guess about the future rather than a rule.
words+='|klar|bedeckt|Nebel|Niesel|Regen|Schnee|Schauer|Gewitter|Wolken|Sonne'
# And one more that sat in the session menu, in the one place where a wrong
# word is pressed by somebody in a hurry: "Ausschalten" beside four English
# labels. Nouns again — the method catches sentences, not labels.
words+='|Ausschalten|Neustart|Abmelden|Sperren|Ruhezustand'
words+='|Anmeldung|abgelehnt|Konto|Stadt|eingeben|Ortssuche|Unsinn|Uhrzeit|Datum'
words+='|Lautstärke|Lautstaerke|Helligkeit|Verbindung|verbunden|getrennt|Passwort'
# And "+ 2 weitere" in the notification list, which shipped. Same limit as
# above: not a function word, not a sentence — a two-word label. It is in now.
words+='|weitere|weiteren|Meldung|Meldungen|Mitteilung|Mitteilungen'

files=$(git ls-files 'shell/*.qml' 'shell/**/*.qml' 'docs/*.md' 'README.md' \
                    'lib/*.sh' 'bin/*' 'install.sh' 'tests/*.sh' 2>/dev/null)

for file in $files; do
    # This file names the words it forbids, so it cannot check itself.
    [[ "$file" == "tests/english.sh" ]] && continue
    while IFS=: read -r line text; do
        [[ -z "${line:-}" ]] && continue
        [[ "$text" == *"english-ok"* ]] && continue
        report "german  $file:$line" \
               "$(printf '%s' "$text" | sed 's/^[[:space:]]*//' | cut -c1-72)"
    done < <(grep -nEi "\\b(${words})\\b" "$file" 2>/dev/null)
done

if (( fail )); then
    cat <<'EOF'

  This repository is public and its plan says English — everywhere, without an
  i18n apparatus. A German label reaches further than it looks: the `desc:`
  fields become the entries in niri's own keyboard-shortcut overlay.

  If a line is right as it stands — the name of a key, a folder that really is
  called that on the machine — say so on the line:

      "Super+Ö"    // english-ok: the name of a physical key

EOF
else
    printf '  no German outside the places that say why\n'
fi
exit $fail
