#!/usr/bin/env bash
# Test granatow przez siec: boty z opoznieniem rzucaja, a na koncu wszyscy musza widziec
# ten sam stan i zaden granat nie moze zostac w powietrzu.
# Uzycie: tools/grenade_net_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-120}"
LOSS="${2:-3}"
SERVER_PORT=7951
PROXY_PORT=7952
LOGS=tools/logs
PROBE=--tool=res://tools/inventory_probe.gd
mkdir -p "$LOGS"

timeout 28 "$GODOT" --path . --headless -- --server --map=forest --port=$SERVER_PORT --debug-items $PROBE > "$LOGS/nade_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" 26 > /dev/null 2>&1 &
sleep 1
timeout 24 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=RzutA --bot=grenadier $PROBE > "$LOGS/nade_a.log" 2>&1 &
timeout 24 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=RzutB --bot=grenadier $PROBE > "$LOGS/nade_b.log" 2>&1 &
wait

FAILED=0
THROWN="$(grep -c 'wybuch granatu' "$LOGS/nade_server.log")"
echo "wybuchy na serwerze: $THROWN"
[ "$THROWN" -ge 2 ] || FAILED=1
for name in server a b; do
	LINE="$(grep '\[loot\]' "$LOGS/nade_$name.log" | tail -1 | grep -oE 'granaty=[0-9]+')"
	echo "$name: $LINE"
	[ "$LINE" = "granaty=0" ] || FAILED=1
	if grep -q 'SCRIPT ERROR' "$LOGS/nade_$name.log"; then
		grep 'SCRIPT ERROR' "$LOGS/nade_$name.log" | cut -c1-150 | sort | uniq -c | head -5
		FAILED=1
	fi
done
grep -h 'granat zadal' "$LOGS/nade_server.log" | head -4
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
