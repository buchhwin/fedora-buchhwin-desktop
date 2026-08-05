#!/usr/bin/env bash
#
# The calendar: reading iCalendar, and the month arithmetic under it.
#
# Every failure in this area looks the same from outside — an appointment on the
# wrong day, or one that never appears at all — and you find out by missing it.
# So the checks live next to the samples they judge, in shell/tools/ical-check.qml,
# and this script only runs them and reports.
#
# Deliberately offline: no account, no network, no clock beyond `new Date()`.
# That is what makes it a CI test rather than something only one machine can run.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

command -v qs >/dev/null || { echo "quickshell (qs) not installed"; exit 2; }

rm -f /tmp/buchhwin-ical-check.txt
BUCHHWIN_TOOL=ical-check QT_QPA_PLATFORM=offscreen timeout 60 qs -p shell >/dev/null 2>&1

if [[ ! -f /tmp/buchhwin-ical-check.txt ]]; then
    echo "  no output — the checker did not run"
    exit 1
fi

# Colour the two words that matter, leave the rest as the tool wrote it.
sed -e 's/^  ok /  \x1b[38;5;114mok\x1b[0m /' \
    -e 's/^  FAIL /  \x1b[38;5;203mFAIL\x1b[0m /' \
    /tmp/buchhwin-ical-check.txt

grep -q '^  FAIL' /tmp/buchhwin-ical-check.txt && exit 1
exit 0
