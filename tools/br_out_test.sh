#!/usr/bin/env bash
# Test eliminacji: C wychodzi z gry w trakcie meczu, serwer zabija A, wiec wygrywa B.
# Spozniony D ma ogladac. Boty nie omijaja drzew, wiec walka nozami nie zawsze sie konczy.
# Drugi przebieg zabija wszystkich w jednej klatce, co ma dac remis.
# Uzycie: tools/br_out_test.sh
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
LOGS=tools/logs
PORT=7875
PROBE="--tool=res://tools/match_probe.gd --auto-ready"
mkdir -p "$LOGS"
FAILED=0

check() {
	if grep -qE "$2" "$1"; then echo "ok: $3"; else echo "BRAK: $3"; FAILED=1; fi
}

timeout 75 "$GODOT" --path . --headless -- --server --map=forest --mode=battle_royale --port=$PORT --tool=res://tools/match_probe.gd --kill-name=A --kill-name-at=6 > "$LOGS/out_server.log" 2>&1 &
sleep 2
timeout 70 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PORT --name=A --bot=runner $PROBE > "$LOGS/out_a.log" 2>&1 &
timeout 70 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PORT --name=B --bot=runner $PROBE > "$LOGS/out_b.log" 2>&1 &
timeout 70 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PORT --name=C --bot=runner $PROBE --quit-after-live=2 > "$LOGS/out_c.log" 2>&1 &
sleep 16
timeout 55 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PORT --name=D > "$LOGS/out_d.log" 2>&1 &
wait
check "$LOGS/out_server.log" 'start meczu, graczy: 3' "mecz startuje z 3 graczami"
check "$LOGS/out_server.log" 'wyszedl C' "C wychodzi w trakcie meczu"
check "$LOGS/out_server.log" 'koniec meczu, zywych: 1' "serwer widzi zwyciezce"
# Po powrocie do lobby odrodzenie jest prawidlowe, wiec liczy sie tylko czas do konca meczu.
sed '/koniec meczu/q' "$LOGS/out_server.log" | grep -q 'wraca do gry' && { echo "ktos sie odrodzil w trakcie meczu"; FAILED=1; }

timeout 26 "$GODOT" --path . --headless -- --server --map=forest --mode=battle_royale --port=$((PORT + 1)) --tool=res://tools/match_probe.gd --kill-all-at=1 > "$LOGS/draw_server.log" 2>&1 &
sleep 2
timeout 22 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$((PORT + 1)) --name=A --bot=runner $PROBE > "$LOGS/draw_a.log" 2>&1 &
timeout 22 "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$((PORT + 1)) --name=B --bot=runner $PROBE > "$LOGS/draw_b.log" 2>&1 &
wait
check "$LOGS/draw_server.log" 'koniec meczu, zywych: 0' "jednoczesna smierc to remis"

if grep -q 'SCRIPT ERROR' "$LOGS"/out_*.log "$LOGS"/draw_*.log; then
	grep -h 'SCRIPT ERROR' "$LOGS"/out_*.log "$LOGS"/draw_*.log | sort | uniq -c | head
	FAILED=1
fi
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
exit $FAILED
