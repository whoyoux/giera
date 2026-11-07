#!/usr/bin/env bash
# Test czatu przez siec: klient z opoznieniem wysyla wiadomosci i spam, a pozostali musza zobaczyc
# to samo. Serwer tnie dlugie wiadomosci i spam, a pozno dolaczony gracz nie dostaje historii.
# Uzycie: tools/chat_net_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-120}"
LOSS="${2:-3}"
SERVER_PORT=7965
PROXY_PORT=7966
LOGS=tools/logs
PROBE=--tool=res://tools/chat_probe.gd
SECONDS_PLAYED=18
mkdir -p "$LOGS"

timeout $((SECONDS_PLAYED + 6)) "$GODOT" --path . --headless -- --server --map=forest --port=$SERVER_PORT > "$LOGS/chat_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" $((SECONDS_PLAYED + 4)) > /dev/null 2>&1 &
sleep 1
timeout $SECONDS_PLAYED "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Pisarz --bot=spectator $PROBE --chat-send > "$LOGS/chat_sender.log" 2>&1 &
timeout $SECONDS_PLAYED "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Czytelnik --bot=spectator $PROBE > "$LOGS/chat_reader.log" 2>&1 &
sleep 9
timeout $((SECONDS_PLAYED - 9)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$SERVER_PORT --name=Spozniony --bot=spectator $PROBE > "$LOGS/chat_late.log" 2>&1 &
wait

FAILED=0
messages() { grep '^\[chat\]' "$1"; }
SENT="$(messages "$LOGS/chat_sender.log")"
READ="$(messages "$LOGS/chat_reader.log")"
echo "$READ" | uniq -c
EXPECTED="$(printf '[chat] Pisarz 14 czesc [b]x[/b]\n[chat] Pisarz 120 yyyyyyyyyyyyyyyy\n'; for _ in 1 2 3 4 5 6; do echo '[chat] Pisarz 4 spam'; done)"
[ "$READ" = "$EXPECTED" ] || { echo "czytelnik dostal co innego niz powinien"; FAILED=1; }
[ "$SENT" = "$READ" ] || { echo "pisarz i czytelnik widza co innego"; FAILED=1; }
if messages "$LOGS/chat_late.log" | grep -q czesc; then
	echo "spozniony dostal stara wiadomosc"
	FAILED=1
fi
if grep -qE 'czesc|spam|yyyy' "$LOGS/chat_server.log"; then
	echo "tresc czatu trafila do logu serwera"
	FAILED=1
fi
for name in server sender reader late; do
	if grep -q 'SCRIPT ERROR' "$LOGS/chat_$name.log"; then
		grep 'SCRIPT ERROR' "$LOGS/chat_$name.log" | cut -c1-150 | sort | uniq -c | head -5
		FAILED=1
	fi
done
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
