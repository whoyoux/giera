#!/usr/bin/env bash
# Mierzy, ile celnych na ekranie strzalow zalicza serwer przy zadanym opoznieniu.
# Uzycie: tools/hit_test.sh [opoznienie_ms_w_kazda_strone] [sekundy] [port]
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-20}"; SECS="${2:-30}"; PORT="${3:-7840}"; PROXY=$((PORT + 1)); L=tools/logs; mkdir -p "$L"
python tools/lag_proxy.py "$PROXY" "$PORT" "$DELAY" 0 $((SECS + 5)) > "$L/proxy.log" 2>&1 &
timeout $((SECS + 6)) "$GODOT" --path . --headless -- --server --port="$PORT" > "$L/server.log" 2>&1 &
S=$!
sleep 2
timeout $((SECS + 3)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port="$PROXY" --name=Cel --bot=runner --tool=res://tools/hit_stats.gd > "$L/runner.log" 2>&1 &
R=$!
sleep 1
timeout "$SECS" "$GODOT" --path . --headless -- --connect=127.0.0.1 --port="$PROXY" --name=Lowca --bot=headhunter --tool=res://tools/hit_stats.gd > "$L/hunter.log" 2>&1
wait "$R" "$S"
echo "opoznienie ${DELAY}ms w kazda strone:"; grep hit_stats "$L/hunter.log" | tail -1; echo "cel:"; grep hit_stats "$L/runner.log" | tail -1
grep -hE 'SCRIPT ERROR' "$L/hunter.log" "$L/server.log" | sort -u | head -5
