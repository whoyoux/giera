#!/usr/bin/env bash
# Test Team Deathmatchu przez siec: cztery strzelajace boty w dwoch druzynach i piaty, ktory
# dolacza pozniej bez wskazania druzyny, wiec trafia do mniejszej. Serwer co chwile sprawdza,
# ze sojusznik nie zadaje obrazen, a koniec rundy ma zgodny wynik druzyn i podium zwyciezcow.
# Uzycie: tools/tdm_net_test.sh [opoznienie_ms] [strata_procent]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-60}"
LOSS="${2:-1}"
SERVER_PORT=7991
PROXY_PORT=7992
LOGS=tools/logs
TOTAL=130
ROUND="--round-seconds=50 --round-kill-limit=6"
mkdir -p "$LOGS"
rm -f "$LOGS"/tdm_*.log

timeout $TOTAL "$GODOT" --path . --headless -- --server --mode=team_deathmatch --map=forest --port=$SERVER_PORT --debug-snipers $ROUND --tool=res://tools/tdm_probe.gd > "$LOGS/tdm_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" $TOTAL > /dev/null 2>&1 &
PROXY=$!
sleep 1
CLIENTS=""
for entry in A:0 B:0 C:1 D:1; do
	name="${entry%%:*}"
	team="${entry##*:}"
	timeout $((TOTAL - 5)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=$name --team=$team --bot=shooter > "$LOGS/tdm_$name.log" 2>&1 &
	CLIENTS="$CLIENTS $!"
done
sleep 20
timeout $((TOTAL - 25)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=E --bot=shooter > "$LOGS/tdm_E.log" 2>&1 &
CLIENTS="$CLIENTS $!"
wait $CLIENTS
kill $PROXY 2>/dev/null
wait

FAILED=0
SERVER="$LOGS/tdm_server.log"
for name in A B; do
	grep -q "$name gra w druzynie Kaktusy" "$SERVER" || { echo "$name nie trafil do Kaktusow"; FAILED=1; }
done
for name in C D; do
	grep -q "$name gra w druzynie Żuczki" "$SERVER" || { echo "$name nie trafil do Zuczkow"; FAILED=1; }
done
grep -q "E gra w druzynie" "$SERVER" && echo "E: $(grep -o 'E gra w druzynie [^ ]*' "$SERVER" | head -1)" || { echo "E nie dostal druzyny"; FAILED=1; }
grep -h '\[tdm\] druzyny' "$SERVER" | grep -vE '\[(2, 2|2, 3|3, 2|1, 2|2, 1|1, 1|0, 1|1, 0|0, 0)\]' | grep -q . && { echo "nierowne druzyny"; FAILED=1; }
CHECKS="$(grep -c 'ogien przyjacielski zablokowany' "$SERVER")"
echo "sprawdzenia ognia przyjacielskiego: $CHECKS"
[ "$CHECKS" -ge 3 ] || FAILED=1
grep -q 'ZADAL OBRAZENIA' "$SERVER" && { echo "sojusznik zadal obrazenia"; FAILED=1; }
grep -q 'SOJUSZNIK$' "$SERVER" && { echo "zabojstwo sojusznika"; FAILED=1; }
KILLS="$(grep -c 'zabojstwo .* wrog' "$SERVER")"
echo "zabojstwa wrogow: $KILLS"
ENDS="$(grep -h 'koniec rundy wynik' "$SERVER")"
echo "$ENDS"
[ -n "$ENDS" ] || { echo "runda sie nie skonczyla"; FAILED=1; }
echo "$ENDS" | while read -r line; do
	score="$(echo "$line" | sed -E 's/.*wynik (\[[0-9, ]*\]) zabojstwa.*/\1/')"
	kills="$(echo "$line" | sed -E 's/.*zabojstwa (\[[0-9, ]*\]) zwyciezca.*/\1/')"
	[ "$score" = "$kills" ] || echo "WYNIK $score ROZNY OD ZABOJSTW $kills"
done | grep -q ROZNY && { echo "wynik druzyn nie zgadza sie z zabojstwami"; FAILED=1; }
grep -h 'podium zaczyna' "$SERVER" | head -2
if grep -q 'SCRIPT ERROR' "$LOGS"/tdm_*.log; then
	grep -h 'SCRIPT ERROR' -A2 "$LOGS"/tdm_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
[ "$FAILED" = 0 ]
