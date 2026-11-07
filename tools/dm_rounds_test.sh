#!/usr/bin/env bash
# Test rund Deathmatchu przez siec z opoznieniem: 3 rundy z rzedu z nozami, jeden bot wychodzi
# w trakcie drugiej rundy, a inny dolacza w jej trakcie. Po kazdej rundzie stan ma byc czysty,
# wyniki takie same u wszystkich, a dolaczajacy musi znac ten sam koniec rundy co serwer.
# Uzycie: tools/dm_rounds_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-80}"
LOSS="${2:-2}"
SERVER_PORT=7981
PROXY_PORT=7982
LOGS=tools/logs
TOTAL=150
ROUND="--round-seconds=25 --round-kill-limit=4"
mkdir -p "$LOGS"

timeout $TOTAL "$GODOT" --path . --headless -- --server --map=forest --port=$SERVER_PORT --debug-weapons $ROUND --tool=res://tools/match_probe.gd > "$LOGS/rounds_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" $TOTAL > /dev/null 2>&1 &
PROXY=$!
sleep 1
for name in A B; do
	timeout $((TOTAL - 5)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=$name --bot=brawler --debug-weapons --tool=res://tools/match_probe.gd > "$LOGS/rounds_$name.log" 2>&1 &
	CLIENTS="${CLIENTS:-} $!"
done
timeout $((TOTAL - 5)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=C --bot=brawler --debug-weapons --quit-in-round=2 --tool=res://tools/match_probe.gd > "$LOGS/rounds_C.log" 2>&1 &
CLIENTS="$CLIENTS $!"
sleep 50
timeout $((TOTAL - 55)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=D --bot=brawler --debug-weapons --tool=res://tools/match_probe.gd > "$LOGS/rounds_D.log" 2>&1 &
CLIENTS="$CLIENTS $!"
wait $CLIENTS
kill $PROXY 2>/dev/null
wait

FAILED=0
ENDED="$(grep -c 'koniec rundy' "$LOGS/rounds_server.log")"
echo "skonczone rundy: $ENDED"
[ "$ENDED" -ge 3 ] || FAILED=1
grep -q 'wyszedl C' "$LOGS/rounds_server.log" && grep -q 'wychodze w trakcie rundy 2' "$LOGS/rounds_C.log" && echo "C wyszedl w trakcie rundy 2" || { echo "C nie wyszedl w rundzie 2"; FAILED=1; }
SERVER_RESULTS="$(grep -h '\[wyniki\]' "$LOGS/rounds_server.log" | head -3)"
for name in server A B; do
	REPORTS="$(grep -h '\[reset\]' "$LOGS/rounds_$name.log")"
	echo "$name: $(echo "$REPORTS" | tail -1)"
	[ "$(echo "$REPORTS" | grep -c '\[reset\]')" -ge 2 ] || { echo "$name: za malo resetow"; FAILED=1; }
	echo "$REPORTS" | grep -v 'przedmioty=0 granaty=0 otwarte=0 brudni=0' | grep -q . && { echo "$name: brudny stan"; FAILED=1; }
done
for name in A B; do
	[ "$(grep -h '\[wyniki\]' "$LOGS/rounds_$name.log" | head -3)" = "$SERVER_RESULTS" ] || { echo "$name: inne wyniki niz serwer"; FAILED=1; }
done
JOIN_ROUND="$(grep -h '\[runda\] numer' "$LOGS/rounds_D.log" | head -1)"
echo "dolaczajacy: $JOIN_ROUND"
[ -n "$JOIN_ROUND" ] && grep -qF "$JOIN_ROUND" "$LOGS/rounds_server.log" || { echo "dolaczajacy zna inny koniec rundy"; FAILED=1; }
echo "$SERVER_RESULTS"
if grep -q 'SCRIPT ERROR' "$LOGS"/rounds_*.log; then
	grep -h 'SCRIPT ERROR' "$LOGS"/rounds_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
