#!/usr/bin/env bash
# Test sieci dla przedmiotow na ziemi: dwa boty przez proxy z opoznieniem i strata pakietow
# wyrzucaja i podnosza bronie, a trzeci gracz dolacza pozniej. Na koncu wszyscy musza
# widziec to samo, a zaden egzemplarz nie moze sie podwoic.
# Uzycie: tools/loot_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-120}"
LOSS="${2:-3}"
SERVER_PORT=7831
PROXY_PORT=7832
LOGS=tools/logs
PROBE=--tool=res://tools/inventory_probe.gd
mkdir -p "$LOGS"

timeout 34 "$GODOT" --path . --headless -- --server --map=forest --port=$SERVER_PORT --debug-items $PROBE > "$LOGS/loot_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" 32 > /dev/null 2>&1 &
sleep 1
timeout 30 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=LootA --bot=looter --bot-seconds=16 $PROBE > "$LOGS/loot_a.log" 2>&1 &
timeout 30 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=LootB --bot=looter --bot-seconds=16 $PROBE > "$LOGS/loot_b.log" 2>&1 &
sleep 12
timeout 18 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$SERVER_PORT --name=Pozny $PROBE > "$LOGS/loot_late.log" 2>&1 &
wait

FAILED=0
REFERENCE=""
for name in server a b late; do
	LINE="$(grep '\[loot\]' "$LOGS/loot_$name.log" | tail -1)"
	echo "$name: $LINE"
	[ -z "$REFERENCE" ] && REFERENCE="$LINE"
	[ "$LINE" = "$REFERENCE" ] || FAILED=1
	if grep '\[loot\]' "$LOGS/loot_$name.log" | grep -qv 'duplikaty=0'; then
		echo "$name: podwojony egzemplarz"
		FAILED=1
	fi
	grep -E 'SCRIPT ERROR|^ERROR' "$LOGS/loot_$name.log" | cut -c1-150 | sort | uniq -c | head -5
done
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "ROZJAZD"
exit $FAILED
