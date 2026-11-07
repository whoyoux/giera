#!/usr/bin/env bash
# Uruchamia testy po kolei i zapisuje tabele: nazwa, wynik, sekundy.
# Uzycie: tools/all_tests.sh [plik_wyniku] [filtr nazw jako wyrazenie grep]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
export GODOT
OUT="${1:-tools/logs/all_tests.txt}"
FILTER="${2:-.}"
LOGS=tools/logs/all
mkdir -p "$LOGS"
: > "$OUT"

USERDATA="${APPDATA:-$HOME/.local/share}/Godot/app_userdata/Giera"

run_case() {
	local name="$1"; shift
	rm -f "$USERDATA/all_$name.cfg"
	echo "$name" | grep -qE "$FILTER" || return 0
	local started=$SECONDS
	"$@" > "$LOGS/$name.log" 2>&1
	local code=$?
	local verdict=OK
	[ "$code" -eq 0 ] || verdict="BLAD($code)"
	if grep -q 'SCRIPT ERROR' "$LOGS/$name.log"; then
		verdict="$verdict+SCRIPT_ERROR"
	fi
	printf '%-22s %-24s %4ds\n' "$name" "$verdict" "$((SECONDS - started))" | tee -a "$OUT"
}

headless() {
	local name="$1"; shift
	run_case "$name" timeout 150 "$GODOT" --headless --path . -- --settings-path="user://all_$name.cfg" --tool="res://tools/$name.gd" "$@"
}

windowed() {
	local name="$1"; shift
	run_case "$name" timeout 240 "$GODOT" --path . --resolution 1280x720 -- --settings-path="user://all_$name.cfg" --tool="res://tools/$name.gd" "$@"
}

while read -r name; do
	[ -n "$name" ] && headless "$name"
done < <(sed -n '/^# HEADLESS/,/^# KONIEC/p' "$0" | sed -n 's/^#- //p')

while read -r line; do
	[ -n "$line" ] && windowed $line
done < <(sed -n '/^# OKNO/,/^# KONIEC/p' "$0" | sed -n 's/^#- //p')

while read -r name; do
	[ -n "$name" ] && run_case "$name" bash "tools/$name.sh"
done < <(sed -n '/^# SIEC/,/^# KONIEC/p' "$0" | sed -n 's/^#- //p')

echo "---"
echo "zaliczone: $(grep -cE ' OK ' "$OUT"), bledne: $(grep -cE 'BLAD|SCRIPT_ERROR' "$OUT")"
exit 0

# HEADLESS
#- items_test
#- hitscan_test
#- remote_motion_test
#- zone_test
# KONIEC
# OKNO
#- aim_test
#- ambience_test
#- character_test
#- chat_test
#- chest_test --debug-chests
#- dance_test
#- feel_test
#- flow_test
#- grenade_test
#- inventory_test --server-items
#- map_test
#- medkit_test
#- pickup_test
#- settings_test
#- steam_account_test --no-steam
#- ui_feel_test
#- weapons_test
#- keybinds_test
#- crouch_test
#- new_weapons_test
# KONIEC
# SIEC
#- bot_test
#- hit_test
#- loot_test
#- chest_test
#- grenade_net_test
#- medkit_net_test
#- steam_net_test
#- weapons_net_test
#- dance_net_test
#- chat_net_test
#- prediction_net_test
#- kill_feed_test
#- br_lobby_test
#- br_out_test
#- br_leave_test
#- br_reset_test
#- crouch_net_test
#- sniper_net_test
# KONIEC
