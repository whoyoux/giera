#!/usr/bin/env bash
# Test wyjsc z gry w Battle Royale. Bez uruchamiania serwera od nowa:
# 1. Zwyciezca wychodzi w czasie wynikow, a nastepny mecz i tak ma sie rozliczyc.
# 2. Wszyscy wychodza w trakcie meczu, a kolejni gracze zaczynaja nowy mecz w lobby.
# Uzycie: tools/br_leave_test.sh
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
LOGS=tools/logs
PORT=7891
PROBE="--tool=res://tools/match_probe.gd --auto-ready --bot=runner"
mkdir -p "$LOGS"
FAILED=0

client() {
	local log="$1" seconds="$2" port="$3" name="$4"
	shift 4
	timeout "$seconds" "$GODOT" --path . --headless -- --connect=127.0.0.1 --port="$port" --name="$name" $PROBE "$@" > "$LOGS/leave_$log.log" 2>&1 &
}

check_count() {
	local found
	found="$(grep -c "$2" "$1")"
	if [ "$found" -ge "$3" ]; then echo "ok: $4"; else echo "BRAK: $4 ($found z $3)"; FAILED=1; fi
}

timeout 70 "$GODOT" --path . --headless -- --server --map=forest --mode=battle_royale --port=$PORT --tool=res://tools/match_probe.gd --kill-name=A,B --kill-name-at=1 > "$LOGS/leave_winner_server.log" 2>&1 &
sleep 2
client winner_w 60 $PORT W --quit-in-results
client winner_a 60 $PORT A
client winner_b 60 $PORT B
wait
check_count "$LOGS/leave_winner_server.log" 'wyszedl W' 1 "zwyciezca wychodzi z gry"
check_count "$LOGS/leave_winner_server.log" 'koniec meczu' 2 "kolejny mecz po wyjsciu zwyciezcy tez sie konczy"

timeout 60 "$GODOT" --path . --headless -- --server --map=forest --mode=battle_royale --port=$((PORT + 1)) --tool=res://tools/match_probe.gd > "$LOGS/leave_empty_server.log" 2>&1 &
sleep 2
client empty_x 25 $((PORT + 1)) X --quit-after-live=1
client empty_y 25 $((PORT + 1)) Y --quit-after-live=1
sleep 18
client empty_p 30 $((PORT + 1)) P
client empty_q 30 $((PORT + 1)) Q
wait
check_count "$LOGS/leave_empty_server.log" 'wyszedl Y' 1 "wszyscy wychodza w trakcie meczu"
# Ostatnie wyjscie od razu konczy mecz, bez czekania na wyniki.
if grep -A1 -E 'wyszedl (X|Y)' "$LOGS/leave_empty_server.log" | grep -q 'etap LOBBY'; then echo "ok: pusty serwer wraca do lobby"; else echo "BRAK: pusty serwer wraca do lobby"; FAILED=1; fi
check_count "$LOGS/leave_empty_server.log" 'start meczu' 2 "nowi gracze zaczynaja kolejny mecz"

if grep -q 'SCRIPT ERROR' "$LOGS"/leave_*.log; then
	grep -h -A1 'SCRIPT ERROR' "$LOGS"/leave_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
