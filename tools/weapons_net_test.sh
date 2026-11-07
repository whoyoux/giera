#!/usr/bin/env bash
# Test strzelby i noza przez siec: boty z opoznieniem walcza ze soba, a na koncu serwer
# musi miec zabojstwa, klienci bledow nie moga zglaszac, a gdy walka ucichnie, zaden egzemplarz
# nie moze sie podwoic. W chwili smierci przedmiot bywa na moment i na ziemi, i w slocie.
# Uzycie: tools/weapons_net_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-120}"
LOSS="${2:-3}"
SERVER_PORT=7953
PROXY_PORT=7954
LOGS=tools/logs
PROBE=--tool=res://tools/inventory_probe.gd
mkdir -p "$LOGS"

timeout 44 "$GODOT" --path . --headless -- --server --map=forest --port=$SERVER_PORT --debug-weapons $PROBE > "$LOGS/arms_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" 42 > /dev/null 2>&1 &
sleep 1
timeout 40 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Noz --bot=brawler --bot-seconds=30 $PROBE > "$LOGS/arms_knife.log" 2>&1 &
timeout 40 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Strzelba --bot=pumper --bot-seconds=30 $PROBE > "$LOGS/arms_shotgun.log" 2>&1 &
wait

FAILED=0
KNIFE_KILLS="$(grep -c 'Noz zabil' "$LOGS/arms_server.log")"
SHOTGUN_KILLS="$(grep -c 'Strzelba zabil' "$LOGS/arms_server.log")"
echo "zabojstwa: noz=$KNIFE_KILLS strzelba=$SHOTGUN_KILLS"
[ "$((KNIFE_KILLS + SHOTGUN_KILLS))" -ge 2 ] || FAILED=1
for name in server knife shotgun; do
	LINE="$(grep '\[loot\]' "$LOGS/arms_$name.log" | tail -1 | grep -oE 'duplikaty=[0-9]+')"
	echo "$name: $LINE"
	[ "$LINE" = "duplikaty=0" ] || FAILED=1
	if grep -q 'SCRIPT ERROR' "$LOGS/arms_$name.log"; then
		grep 'SCRIPT ERROR' "$LOGS/arms_$name.log" | cut -c1-150 | sort | uniq -c | head -5
		FAILED=1
	fi
done
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
