#!/usr/bin/env bash
# Test apteczki przez siec: bot z opoznieniem leczy sie, a serwer co kilka sekund go rani.
# Jedno leczenie nie moze zaczynac sie wiele razy mimo opoznionej odpowiedzi serwera.
# Uzycie: tools/medkit_net_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-120}"
LOSS="${2:-3}"
SERVER_PORT=7861
PROXY_PORT=7862
LOGS=tools/logs
PROBE=--tool=res://tools/heal_probe.gd
mkdir -p "$LOGS"

timeout 24 "$GODOT" --path . --headless -- --server --port=$SERVER_PORT --debug-items --debug-medkit $PROBE > "$LOGS/heal_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" 22 > /dev/null 2>&1 &
sleep 1
timeout 20 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Medyk --bot=medic $PROBE > "$LOGS/heal_client.log" 2>&1 &
wait

HEALS="$(grep -c 'uleczyl sie' "$LOGS/heal_server.log")"
LAST="$(grep '\[heal\]' "$LOGS/heal_client.log" | tail -1)"
echo "leczenia na serwerze: $HEALS"
echo "$LAST"
grep -hE 'SCRIPT ERROR' "$LOGS/heal_server.log" "$LOGS/heal_client.log" | cut -c1-150 | sort | uniq -c
[ "$HEALS" -ge 1 ] && ! grep -q 'SCRIPT ERROR' "$LOGS/heal_server.log" "$LOGS/heal_client.log" && echo "WSZYSTKO OK" || { echo "BLAD"; exit 1; }
