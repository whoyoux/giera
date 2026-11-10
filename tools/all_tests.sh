#!/usr/bin/env bash
# Uruchamia testy po kolei i zapisuje tabele: nazwa, wynik, sekundy.
# Uzycie: tools/all_tests.sh [plik_wyniku] [filtr nazw jako wyrazenie grep]
# HIDE_WINDOWS=1 otwiera okna testow daleko poza ekranem, zeby nie zaslanialy pulpitu.
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

## Test z flaga --mode=X dostaje w tabeli nazwe nazwa_X, zeby kilka trybow mialo osobne wiersze i logi.
headless() {
	local name="$1"; shift
	local label="$name"
	for arg in "$@"; do
		case "$arg" in --mode=*) label="${name}_${arg#--mode=}" ;; esac
	done
	run_case "$label" timeout 150 "$GODOT" --headless --path . -- --settings-path="user://all_$label.cfg" --map="${MAP:-forest}" --tool="res://tools/$name.gd" "$@"
}

## Starsze testy znaja wspolrzedne lesnej polany, wiec domyslnie graja na niej. Test innej mapy
## podaje wlasne --map= po nazwie, a ostatnia wartosc wygrywa.
windowed() {
	local name="$1"; shift
	local hide=()
	[ "${HIDE_WINDOWS:-0}" = 1 ] && hide=(--position 20000,20000)
	run_case "$name" timeout 240 "$GODOT" --path . --resolution 1280x720 "${hide[@]}" -- --settings-path="user://all_$name.cfg" --map="${MAP:-forest}" --tool="res://tools/$name.gd" "$@"
}

while read -r line; do
	[ -n "$line" ] && headless $line
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
#- hud_layout_test --mode=deathmatch --map=desert
#- hud_layout_test --mode=team_deathmatch --map=desert
#- hud_layout_test --mode=battle_royale --map=valley
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
#- regen_test
#- round_test --round-seconds=40 --round-kill-limit=3
#- city_map_test --map=city
#- valley_map_test --map=valley
#- desert_map_test --map=desert
#- features_test
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
#- regen_net_test
#- dm_rounds_test
#- city_bots_test
#- br_valley_test
#- tdm_net_test
# KONIEC
