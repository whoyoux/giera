#!/usr/bin/env bash
# Test kucania przez siec z opoznieniem: bot kuca i wstaje, a dwa boty strzelaja tam, gdzie bylaby
# glowa stojacego. Ten, ktory strzela tylko w kucajacego, nie moze trafic, a drugi musi.
# Uzycie: tools/crouch_net_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-120}"
LOSS="${2:-2}"
SERVER_PORT=7971
PROXY_PORT=7972
LOGS=tools/logs
PROBE=--tool=res://tools/crouch_probe.gd
mkdir -p "$LOGS"

timeout 68 "$GODOT" --path . --headless -- --server --port=$SERVER_PORT > "$LOGS/crouch_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" 66 > /dev/null 2>&1 &
sleep 1
timeout 64 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Kucacz --bot=ducker > "$LOGS/crouch_ducker.log" 2>&1 &
timeout 62 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=NadKucajacym --bot=overhead --bot-target=Kucacz --aim-when=crouched $PROBE > "$LOGS/crouch_low.log" 2>&1 &
timeout 62 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=NadStojacym --bot=overhead --bot-target=Kucacz --aim-when=standing $PROBE > "$LOGS/crouch_high.log" 2>&1 &
wait

FAILED=0
LOW="$(grep '\[nad_glowa\]' "$LOGS/crouch_low.log" | tail -1)"
HIGH="$(grep '\[nad_glowa\]' "$LOGS/crouch_high.log" | tail -1)"
echo "w kucajacego: $LOW"
echo "w stojacego: $HIGH"
LOW_SHOTS="$(echo "$LOW" | grep -oE 'strzaly=[0-9]+' | cut -d= -f2)"
LOW_HITS="$(echo "$LOW" | grep -oE 'trafienia=[0-9]+' | cut -d= -f2)"
HIGH_HITS="$(echo "$HIGH" | grep -oE 'trafienia=[0-9]+' | cut -d= -f2)"
[ "${LOW_SHOTS:-0}" -ge 3 ] || { echo "za malo strzalow w kucajacego"; FAILED=1; }
[ "${LOW_HITS:-1}" -eq 0 ] || { echo "strzal nad kucajacym trafil"; FAILED=1; }
[ "${HIGH_HITS:-0}" -ge 1 ] || { echo "stojacy nie dostal"; FAILED=1; }
if grep -q 'SCRIPT ERROR' "$LOGS"/crouch_*.log; then
	grep -h 'SCRIPT ERROR' "$LOGS"/crouch_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
