#!/usr/bin/env bash
# Test sieci bez okien: serwer dedykowany i dwa boty przez zadany czas.
# Uzycie: tools/bot_test.sh [sekundy] [port serwera] [port dla klientow]
# Klienci moga laczyc sie przez inny port, np. przez proxy z opoznieniem.
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
SECONDS_TO_RUN="${1:-25}"
SERVER_PORT="${2:-7801}"
CLIENT_PORT="${3:-$SERVER_PORT}"
LOGS=tools/logs
mkdir -p "$LOGS"

timeout $((SECONDS_TO_RUN + 6)) "$GODOT" --path . --headless -- --server --map=forest --port="$SERVER_PORT" > "$LOGS/server.log" 2>&1 &
SERVER=$!
sleep 2
timeout $((SECONDS_TO_RUN + 3)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port="$CLIENT_PORT" --name=Cel --bot=runner > "$LOGS/runner.log" 2>&1 &
RUNNER=$!
sleep 1
timeout "$SECONDS_TO_RUN" "$GODOT" --path . --headless -- --connect=127.0.0.1 --port="$CLIENT_PORT" --name=Strzelec --bot=shooter > "$LOGS/shooter.log" 2>&1
wait "$RUNNER" "$SERVER"

for name in server runner shooter; do
	echo "=== $name"
	grep -vE '^\s*$|Godot Engine|^Vulkan|^OpenGL|\[DBG\]|unref|Unreferenced|PagedAllocator|Thread object|wait_to_finish' "$LOGS/$name.log" \
		| cut -c1-170 | sed -E 's/@[0-9]+/@N/; s/[0-9]{6,}/ID/g' | sort | uniq -c | sort -rn | head -"${TOP_LINES:-18}"
done
