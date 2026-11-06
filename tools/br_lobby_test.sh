#!/usr/bin/env bash
# Test lobby Battle Royale przez proxy z opoznieniem. A i B klikaja Gotowe, B cofa gotowosc,
# co przerywa odliczanie, pozniej C dolacza i tez je przerywa. Na koncu mecz startuje.
# Uzycie: tools/br_lobby_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-120}"
LOSS="${2:-3}"
SERVER_PORT=7871
PROXY_PORT=7872
LOGS=tools/logs
PROBE="--tool=res://tools/match_probe.gd --bot=runner"
mkdir -p "$LOGS"

timeout 44 "$GODOT" --path . --headless -- --server --mode=battle_royale --port=$SERVER_PORT > "$LOGS/lobby_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" 44 > /dev/null 2>&1 &
PROXY=$!
sleep 1
timeout 40 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=A $PROBE --ready-at=3 > "$LOGS/lobby_a.log" 2>&1 &
timeout 40 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=B $PROBE --ready-at=4 --unready-at=7 --ready-again-at=11 > "$LOGS/lobby_b.log" 2>&1 &
# Odliczanie z 11. sekundy przerywa C, ktory dolacza niedlugo po nim.
sleep 12
timeout 28 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=C $PROBE --ready-at=6 > "$LOGS/lobby_c.log" 2>&1 &
sleep 29
kill $PROXY 2>/dev/null
wait

FAILED=0
PHASES="$(grep '\[serwer\] etap' "$LOGS/lobby_server.log" | sed 's/.*etap //' | tr '\n' ' ')"
echo "etapy: $PHASES"
[ "$PHASES" = "COUNTDOWN LOBBY COUNTDOWN LOBBY COUNTDOWN STARTING LIVE " ] || FAILED=1
SPOTS=""
for name in a b c; do
	LINE="$(grep '\[freeze\]' "$LOGS/lobby_$name.log" | tail -1)"
	echo "$name: $LINE"
	MOVED="$(echo "$LINE" | sed -E 's/.*ruch=([0-9.]+).*/\1/')"
	python -c "import sys; sys.exit(0 if float('${MOVED:-99}') < 0.05 else 1)" || FAILED=1
	SPOTS="$SPOTS $(echo "$LINE" | sed -E 's/.*punkt=([0-9-]+).*/\1/')"
done
[ "$(echo $SPOTS | tr ' ' '\n' | sort -u | wc -l)" = 3 ] || { echo "powtorzony punkt: $SPOTS"; FAILED=1; }
if grep -q 'SCRIPT ERROR' "$LOGS"/lobby_*.log; then
	grep -h 'SCRIPT ERROR' "$LOGS"/lobby_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
