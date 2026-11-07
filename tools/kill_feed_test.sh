#!/usr/bin/env bash
# Test listy zabojstw przez siec: boty zabijaja sie nozem, a klient bez broni ma widziec nazwe tej broni.
# Uzycie: tools/kill_feed_test.sh
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
LOGS=tools/logs
PORT=7897
SECONDS_TOTAL=60
mkdir -p "$LOGS"

timeout $SECONDS_TOTAL "$GODOT" --path . --headless -- --server --map=forest --mode=deathmatch --port=$PORT --debug-weapons > "$LOGS/feed_server.log" 2>&1 &
sleep 2
for name in A B; do
	timeout $((SECONDS_TOTAL - 4)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PORT --name=$name --bot=brawler > "$LOGS/feed_$name.log" 2>&1 &
done
timeout $((SECONDS_TOTAL - 4)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PORT --name=Widz --bot=none --tool=res://tools/match_probe.gd > "$LOGS/feed_watch.log" 2>&1 &
wait

FAILED=0
KILLS="$(grep -c 'zabil' "$LOGS/feed_server.log")"
SEEN="$(grep -c '\[zabojstwo\].*Nóż' "$LOGS/feed_watch.log")"
echo "zabojstwa na serwerze: $KILLS, klient widzial z nozem: $SEEN"
[ "$KILLS" -gt 0 ] && [ "$SEEN" -gt 0 ] || FAILED=1
if grep -q 'SCRIPT ERROR' "$LOGS"/feed_*.log; then
	grep -h 'SCRIPT ERROR' "$LOGS"/feed_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
