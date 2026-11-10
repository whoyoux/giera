#!/usr/bin/env bash
# Pomiar opoznienia widoku innych graczy: serwer i boty na jednym komputerze. Pierwszy bot (mierzony)
# laczy sie bez opoznienia, ostatni przez tools/lag_proxy.py. Wypisuje co 5 s srednie opoznienie
# widoku u mierzonego bota (ten sam licznik co linia "Widok innych" w wykresie sieci).
# Uzycie: tools/view_delay_test.sh [boty=4] [opoznienie_wolnego_ms=150] [strata_procent=0] [sekundy=30] [wszyscy=0]
# Z opoznieniem 0 wszyscy lacza sie bez proxy. Z wszyscy=1 przez proxy lacza sie wszystkie boty.
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
BOTS="${1:-4}"
DELAY="${2:-150}"
LOSS="${3:-0}"
SECS="${4:-30}"
ALL="${5:-0}"
PORT=7951
PROXY_PORT=7952
LOGS=tools/logs
PROBE=res://tools/net_load_probe.gd
mkdir -p "$LOGS"
rm -f "$LOGS"/view_delay_*.log

timeout $((SECS + 12)) "$GODOT" --path . --headless -- --server --map=city --port=$PORT > "$LOGS/view_delay_server.log" 2>&1 &
sleep 3
if [ "$DELAY" != 0 ]; then
	python tools/lag_proxy.py $PROXY_PORT $PORT "$DELAY" "$LOSS" $((SECS + 8)) > /dev/null 2>&1 &
	sleep 1
fi
for i in $(seq 1 "$BOTS"); do
	TARGET=$PORT
	[ "$DELAY" != 0 ] && { [ "$i" = "$BOTS" ] || [ "$ALL" = 1 ]; } && TARGET=$PROXY_PORT
	TOOL=()
	[ "$i" = 1 ] && TOOL=(--tool=$PROBE)
	timeout $((SECS + 4)) "$GODOT" --path . --headless --max-fps 60 -- --connect=127.0.0.1 --port=$TARGET --name=Bot$i --bot=runner "${TOOL[@]}" > "$LOGS/view_delay_bot$i.log" 2>&1 &
	sleep 0.4
done
wait

echo "== widok u Bot1, przez proxy: $([ "$ALL" = 1 ] && echo wszyscy || echo ostatni bot), ${DELAY} ms w kazda strone, strata ${LOSS}%"
grep '\[widok\]' "$LOGS/view_delay_bot1.log" | tail -4
