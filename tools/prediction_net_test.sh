#!/usr/bin/env bash
# Test przewidywania ruchu: bot z opoznieniem biega i skacze, a klient musi przewidziec to samo co serwer.
# Uzycie: tools/prediction_net_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-30}"
LOSS="${2:-0}"
SERVER_PORT=7971
PROXY_PORT=7972
LOGS=tools/logs
SECONDS_PLAYED=30
# Rzadki pojedynczy rozjazd nie jest widoczny, a przed naprawa bylo ich kilkanascie na taki test.
MAX_ERRORS=2
mkdir -p "$LOGS"

timeout $((SECONDS_PLAYED + 10)) "$GODOT" --path . --headless -- --server --port=$SERVER_PORT > "$LOGS/prediction_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" $((SECONDS_PLAYED + 6)) > /dev/null 2>&1 &
sleep 1
timeout $((SECONDS_PLAYED + 5)) "$GODOT" --path . --headless --max-fps 60 -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Skoczek --bot=runner --tool=res://tools/prediction_probe.gd --probe-seconds=$SECONDS_PLAYED > "$LOGS/prediction_client.log" 2>&1
wait

RESULT="$(grep '\[prediction\]' "$LOGS/prediction_client.log")"
echo "$RESULT"
COMPARED="$(echo "$RESULT" | sed -nE 's/.*stany=([0-9]+).*/\1/p')"
POSITION="$(echo "$RESULT" | sed -nE 's/.*pozycja=([0-9]+).*/\1/p')"
VELOCITY="$(echo "$RESULT" | sed -nE 's/.*predkosc=([0-9]+).*/\1/p')"
if [ -z "$COMPARED" ] || [ "$COMPARED" -lt 100 ]; then
	echo "BLAD: za malo porownanych stanow"
	exit 1
fi
if [ "$POSITION" -gt $MAX_ERRORS ] || [ "$VELOCITY" -gt $MAX_ERRORS ]; then
	echo "BLAD: klient przewiduje inaczej niz serwer"
	exit 1
fi
echo "WSZYSTKO OK"
