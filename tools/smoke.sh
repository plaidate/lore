#!/bin/bash
# Lore smoke runner: build the instrumented variant, run it in the
# Playdate Simulator, poll the datastore, report.
#
#   tools/smoke.sh <game> [seconds] [until-grep]
#
# e.g. tools/smoke.sh slice 180 '"laps":[1-9]'

set -u
GAME="${1:?usage: smoke.sh <game> [seconds] [until-grep]}"
SECS="${2:-180}"
UNTIL="${3:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TITLE="$(echo "$GAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
BUNDLE="com.sdwfrost.lore.$GAME"
DATA="$HOME/Developer/PlaydateSDK/Disk/Data/$BUNDLE"
SIM="$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator"
SHOT="$ROOT/build/$GAME-shot.png"

cd "$ROOT"
make "$GAME-smoke" >/dev/null || { echo "BUILD FAILED"; exit 1; }

pkill -9 -f "Playdate Simulator" 2>/dev/null
rm -rf "$DATA" "$SHOT"
("$SIM" "$ROOT/out/${TITLE}Smoke.pdx" >"$ROOT/build/$GAME-sim.log" 2>&1 &)

ITER=$((SECS / 5))
for i in $(seq 1 "$ITER"); do
    [ -s "$DATA/err.json" ] && break
    if [ -n "$UNTIL" ] && grep -qE "$UNTIL" "$DATA/smoke.json" 2>/dev/null; then
        break
    fi
    sleep 5
done

echo "--- err:"
cat "$DATA/err.json" 2>/dev/null || echo "no error"
echo "--- smoke:"
cat "$DATA/smoke.json" 2>/dev/null || echo "NO HEARTBEAT"
echo
[ -f "$SHOT" ] && echo "screenshot: $SHOT"

pkill -9 -f "Playdate Simulator" 2>/dev/null
mkdir -p "$ROOT/results"
cp "$DATA/smoke.json" "$ROOT/results/$GAME.json" 2>/dev/null
rm -rf "$DATA"
