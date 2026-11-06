#!/usr/bin/env bash
# Test resetu: 3 mecze z rzedu z nozami, przedmiotami z debugu i skrzynkami. Po kazdym meczu
# serwer i klienci musza zglosic czysty stan, a skrzynka nie moze wrocic w trakcie meczu.
# Uzycie: tools/br_reset_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-80}"
LOSS="${2:-2}"
SERVER_PORT=7881
PROXY_PORT=7882
LOGS=tools/logs
SECONDS_TOTAL=110
PROBE="--tool=res://tools/match_probe.gd --auto-ready --debug-weapons"
mkdir -p "$LOGS"

timeout $SECONDS_TOTAL "$GODOT" --path . --headless -- --server --mode=battle_royale --port=$SERVER_PORT --debug-weapons --tool=res://tools/match_probe.gd > "$LOGS/reset_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" $SECONDS_TOTAL > /dev/null 2>&1 &
PROXY=$!
sleep 1
for name in A B C; do
	timeout $((SECONDS_TOTAL - 5)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=$name --bot=brawler $PROBE > "$LOGS/reset_$name.log" 2>&1 &
	CLIENTS="${CLIENTS:-} $!"
done
wait $CLIENTS
kill $PROXY 2>/dev/null
wait

FAILED=0
ENDED="$(grep -c 'koniec meczu' "$LOGS/reset_server.log")"
echo "skonczone mecze: $ENDED"
[ "$ENDED" -ge 3 ] || FAILED=1
for name in server A B C; do
	grep -h '\[wyniki\]' "$LOGS/reset_$name.log" | head -1
	REPORTS="$(grep -h '\[reset\]' "$LOGS/reset_$name.log")"
	echo "$name: $(echo "$REPORTS" | tail -1)"
	[ "$(echo "$REPORTS" | grep -c '\[reset\]')" -ge 3 ] || { echo "$name: za malo resetow"; FAILED=1; }
	echo "$REPORTS" | grep -vq 'przedmioty=0 granaty=0 otwarte=0 brudni=0' && { echo "$name: brudny stan"; FAILED=1; }
done
if grep -q 'SCRIPT ERROR' "$LOGS"/reset_*.log; then
	grep -h 'SCRIPT ERROR' "$LOGS"/reset_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
