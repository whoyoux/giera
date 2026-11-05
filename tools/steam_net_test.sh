#!/usr/bin/env bash
# Test sieci bez okien: gracz ze Steamem, gracz bez Steama i klient ze zmyslonym ID.
# Uzycie: tools/steam_net_test.sh [port]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
PORT="${1:-7821}"
OWN_ID=76561197960265729
LOGS=tools/logs
mkdir -p "$LOGS"

timeout 22 "$GODOT" --path . --headless -- --server --port="$PORT" > "$LOGS/steam_server.log" 2>&1 &
SERVER=$!
sleep 2
timeout 18 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port="$PORT" --name=Beta --bot=runner > "$LOGS/steam_beta.log" 2>&1 &
BETA=$!
timeout 18 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port="$PORT" --fake-steam=Zly:123 --bot=runner > "$LOGS/steam_bad.log" 2>&1 &
BAD=$!
timeout 18 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port="$PORT" --fake-steam=Alfa:$OWN_ID --bot=runner --tool=res://tools/steam_net_probe.gd > "$LOGS/steam_alfa.log" 2>&1
RESULT=$?
wait "$BETA" "$BAD"
kill "$SERVER" 2>/dev/null
wait "$SERVER" 2>/dev/null

grep "^\[test\]" "$LOGS/steam_alfa.log"
if grep -q "$OWN_ID" "$LOGS/steam_server.log"; then
	echo "[test] BLAD: SteamID w logu serwera"
	RESULT=1
fi
if grep -q "SCRIPT ERROR" "$LOGS"/steam_*.log; then
	grep -h "SCRIPT ERROR" "$LOGS"/steam_*.log | sort -u | head
	RESULT=1
fi
exit "$RESULT"
