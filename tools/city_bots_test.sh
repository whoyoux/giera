#!/usr/bin/env bash
# Test miasteczka z botami przez siec: trzy boty walcza na mapie miejskiej. Kazdy klient musi
# wczytac miasto od serwera, boty maja sie znajdowac i zabijac, a nikt nie moze zglosic bledu.
# Uzycie: tools/city_bots_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-80}"
LOSS="${2:-2}"
SERVER_PORT=7983
PROXY_PORT=7984
LOGS=tools/logs
mkdir -p "$LOGS"

timeout 94 "$GODOT" --path . --headless -- --server --port=$SERVER_PORT --debug-weapons > "$LOGS/city_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" 92 > /dev/null 2>&1 &
sleep 1
timeout 90 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Noz1 --bot=brawler > "$LOGS/city_a.log" 2>&1 &
timeout 90 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Strzelba --bot=pumper > "$LOGS/city_b.log" 2>&1 &
timeout 90 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Noz2 --bot=brawler > "$LOGS/city_c.log" 2>&1 &
wait

FAILED=0
grep -q '\[mapa\] city' "$LOGS/city_server.log" || { echo "serwer nie gra w miescie"; FAILED=1; }
for name in a b c; do
	grep -q '\[mapa\] city' "$LOGS/city_$name.log" || { echo "klient $name nie wczytal miasta"; FAILED=1; }
done
KILLS="$(grep -c ' zabil ' "$LOGS/city_server.log")"
KILLERS="$(grep ' zabil ' "$LOGS/city_server.log" | awk '{print $2}' | sort -u | wc -l)"
echo "zabojstwa: $KILLS, rozni zabojcy: $KILLERS"
[ "$KILLS" -ge 4 ] && [ "$KILLERS" -ge 2 ] || FAILED=1
if grep -q 'SCRIPT ERROR' "$LOGS"/city_*.log; then
	grep -h 'SCRIPT ERROR' "$LOGS"/city_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
