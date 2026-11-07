#!/usr/bin/env bash
# Test Battle Royale w dolinie: 2 pelne mecze z rzedu z nozami, przedmiotami z debugu i skrzynkami. Po kazdym meczu
# serwer i klienci musza zglosic czysty stan. Szybka strefa konczy mecz, gdy boty sie nie znajda.
# Ziarno strefy musi byc u wszystkich takie samo.
# Uzycie: tools/br_valley_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-80}"
LOSS="${2:-2}"
SERVER_PORT=7985
PROXY_PORT=7986
LOGS=tools/logs
SECONDS_TOTAL=160
PROBE="--tool=res://tools/match_probe.gd --auto-ready --debug-weapons"
mkdir -p "$LOGS"

timeout $SECONDS_TOTAL "$GODOT" --path . --headless -- --server --map=valley --mode=battle_royale --port=$SERVER_PORT --debug-weapons --zone-speed=12 --tool=res://tools/match_probe.gd > "$LOGS/valley_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" $SECONDS_TOTAL > /dev/null 2>&1 &
PROXY=$!
sleep 1
for name in A B C; do
	timeout $((SECONDS_TOTAL - 5)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=$name --bot=brawler $PROBE > "$LOGS/valley_$name.log" 2>&1 &
	CLIENTS="${CLIENTS:-} $!"
done
wait $CLIENTS
kill $PROXY 2>/dev/null
wait

FAILED=0
ENDED="$(grep -c 'koniec meczu' "$LOGS/valley_server.log")"
echo "skonczone mecze: $ENDED"
[ "$ENDED" -ge 2 ] || FAILED=1
for name in server A B C; do
	grep -h '\[wyniki\]' "$LOGS/valley_$name.log" | head -1
	REPORTS="$(grep -h '\[reset\]' "$LOGS/valley_$name.log")"
	echo "$name: $(echo "$REPORTS" | tail -1)"
	[ "$(echo "$REPORTS" | grep -c '\[reset\]')" -ge 2 ] || { echo "$name: za malo resetow"; FAILED=1; }
	echo "$REPORTS" | grep -vq 'przedmioty=0 granaty=0 otwarte=0 brudni=0' && { echo "$name: brudny stan"; FAILED=1; }
done
for name in A B C; do
	[ "$(grep -h '\[strefa\]' "$LOGS/valley_$name.log" | head -3)" = "$(grep -h '\[strefa\]' "$LOGS/valley_server.log" | head -3)" ] || { echo "$name: inna strefa"; FAILED=1; }
done
grep -q 'Strefa zabil' "$LOGS/valley_server.log" && echo "strefa zabija"
if grep -q 'SCRIPT ERROR' "$LOGS"/valley_*.log; then
	grep -h 'SCRIPT ERROR' "$LOGS"/valley_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
