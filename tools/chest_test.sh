#!/usr/bin/env bash
# Test sieci dla skrzynek: dwa boty przez proxy z opoznieniem otwieraja skrzynki przy punktach
# odrodzenia, a trzeci gracz dolacza pozniej. Na koncu wszyscy musza widziec to samo.
# Uzycie: tools/chest_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-120}"
LOSS="${2:-3}"
SERVER_PORT=7851
PROXY_PORT=7852
LOGS=tools/logs
EXTRA="--debug-chests --tool=res://tools/inventory_probe.gd"
mkdir -p "$LOGS"

timeout 34 "$GODOT" --path . --headless -- --server --map=forest --port=$SERVER_PORT $EXTRA > "$LOGS/chest_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" 32 > /dev/null 2>&1 &
sleep 1
timeout 30 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=OpenA --bot=opener --bot-seconds=16 $EXTRA > "$LOGS/chest_a.log" 2>&1 &
timeout 30 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=OpenB --bot=opener --bot-seconds=16 $EXTRA > "$LOGS/chest_b.log" 2>&1 &
sleep 12
timeout 18 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$SERVER_PORT --name=Pozny $EXTRA > "$LOGS/chest_late.log" 2>&1 &
wait

FAILED=0
REFERENCE=""
for name in server a b late; do
	LINE="$(grep '\[loot\]' "$LOGS/chest_$name.log" | tail -1)"
	echo "$name: $LINE"
	[ -z "$REFERENCE" ] && REFERENCE="$LINE"
	[ "$LINE" = "$REFERENCE" ] || FAILED=1
	if grep '\[loot\]' "$LOGS/chest_$name.log" | grep -qv 'duplikaty=0'; then
		echo "$name: podwojony egzemplarz"
		FAILED=1
	fi
	grep -E 'SCRIPT ERROR|^ERROR' "$LOGS/chest_$name.log" | grep -vE 'Unreferenced|leaked' | cut -c1-150 | sort | uniq -c | head -5
done
if grep -q 'SCRIPT ERROR' "$LOGS"/chest_*.log; then
	echo "blad skryptu w logach"
	FAILED=1
fi
OPENED="$(grep -c 'otworzyl skrzynke' "$LOGS/chest_server.log")"
echo "otwarcia: $OPENED"
[ "$OPENED" -gt 0 ] || FAILED=1
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "ROZJAZD"
exit $FAILED
