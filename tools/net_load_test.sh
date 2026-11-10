#!/usr/bin/env bash
# Pomiar obciazenia sieci: serwer i boty na jednym komputerze. Wypisuje ruch ENet (KB/s, pakiety/s)
# i czas petli tickow serwera oraz pierwszego bota. Sluzy do porownania przed zmiana i po niej,
# wiec obie proby trzeba zrobic na tym samym komputerze, jedna po drugiej.
# Uzycie: tools/net_load_test.sh [boty=16] [sekundy=30] [opoznienie_ms=0] [dodatkowe flagi serwera]
# Przyklad: tools/net_load_test.sh 16 30 0 --no-diff
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
BOTS="${1:-16}"
SECS="${2:-30}"
DELAY="${3:-0}"
EXTRA="${4:-}"
PORT=7941
CLIENT_PORT=$PORT
LOGS=tools/logs
PROBE=res://tools/net_load_probe.gd
mkdir -p "$LOGS"
rm -f "$LOGS"/net_load_*.log

timeout $((SECS + 12)) "$GODOT" --path . --headless -- --server --map=city --port=$PORT $EXTRA --tool=$PROBE > "$LOGS/net_load_server.log" 2>&1 &
sleep 3
if [ "$DELAY" != 0 ]; then
	CLIENT_PORT=7942
	python tools/lag_proxy.py $CLIENT_PORT $PORT "$DELAY" 1 $((SECS + 8)) > /dev/null 2>&1 &
	sleep 1
fi
for i in $(seq 1 "$BOTS"); do
	MODE=runner
	[ $((i % 2)) = 0 ] && MODE=shooter
	TOOL=()
	[ "$i" = 1 ] && TOOL=(--tool=$PROBE)
	timeout $((SECS + 4)) "$GODOT" --path . --headless --max-fps 60 -- --connect=127.0.0.1 --port=$CLIENT_PORT --name=Bot$i --bot=$MODE "${TOOL[@]}" > "$LOGS/net_load_bot$i.log" 2>&1 &
	sleep 0.4
done
wait

# Ostatnia probka serwera bywa niepelna, bo boty juz wychodza, wiec liczy sie przedostatnia.
echo "== serwer"
grep '\[traffic\]' "$LOGS/net_load_server.log" | tail -4
echo "== klient (Bot1)"
grep '\[traffic\]' "$LOGS/net_load_bot1.log" | tail -4
