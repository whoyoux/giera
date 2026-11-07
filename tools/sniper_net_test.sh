#!/usr/bin/env bash
# Test AWP przez siec z opoznieniem: bot w lunecie strzela do bota, ktory kuca i wstaje.
# Kazde trafienie musi zabic, a zaden egzemplarz broni nie moze sie podwoic.
# Uzycie: tools/sniper_net_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-120}"
LOSS="${2:-2}"
SERVER_PORT=7975
PROXY_PORT=7976
LOGS=tools/logs
PROBE=--tool=res://tools/inventory_probe.gd
mkdir -p "$LOGS"

timeout 58 "$GODOT" --path . --headless -- --server --port=$SERVER_PORT --debug-snipers $PROBE > "$LOGS/sniper_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" 56 > /dev/null 2>&1 &
sleep 1
timeout 54 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Kucacz --bot=ducker $PROBE > "$LOGS/sniper_target.log" 2>&1 &
timeout 52 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Snajper --bot=sniper --bot-target=Kucacz $PROBE > "$LOGS/sniper_shooter.log" 2>&1 &
wait

FAILED=0
KILLS="$(grep -c 'Snajper zabil Kucacz' "$LOGS/sniper_server.log")"
echo "zabojstwa z AWP: $KILLS"
[ "$KILLS" -ge 2 ] || FAILED=1
for name in server target shooter; do
	LINE="$(grep '\[loot\]' "$LOGS/sniper_$name.log" | tail -1 | grep -oE 'duplikaty=[0-9]+')"
	echo "$name: $LINE"
	[ "$LINE" = "duplikaty=0" ] || FAILED=1
done
if grep -q 'SCRIPT ERROR' "$LOGS"/sniper_*.log; then
	grep -h 'SCRIPT ERROR' "$LOGS"/sniper_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
