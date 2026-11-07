#!/usr/bin/env bash
# Test regeneracji przez siec z opoznieniem: serwer rani bota, a w trakcie leczenia trafia go znowu.
# Serwer i klient musza zobaczyc, ze leczenie stanelo na 6 s, a potem ruszylo.
# Uzycie: tools/regen_net_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-120}"
LOSS="${2:-2}"
SERVER_PORT=7977
PROXY_PORT=7978
LOGS=tools/logs
PROBE=--tool=res://tools/regen_probe.gd
mkdir -p "$LOGS"

timeout 42 "$GODOT" --path . --headless -- --server --port=$SERVER_PORT $PROBE > "$LOGS/regen_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" 40 > /dev/null 2>&1 &
sleep 1
timeout 38 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Ranny --bot=runner $PROBE > "$LOGS/regen_client.log" 2>&1 &
wait

SERVER="$(grep '\[regen\] serwer: leczyl' "$LOGS/regen_server.log")"
CLIENT="$(grep '\[regen\] klient' "$LOGS/regen_client.log")"
echo "$SERVER"
echo "$CLIENT"
FAILED=0
[ "$SERVER" = "[regen] serwer: leczyl=true przerwane=true potem=true" ] || FAILED=1
[ "$CLIENT" = "[regen] klient: przerwane=true potem=true" ] || FAILED=1
if grep -q 'SCRIPT ERROR' "$LOGS"/regen_*.log; then
	grep -h 'SCRIPT ERROR' "$LOGS"/regen_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
