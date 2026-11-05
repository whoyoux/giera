#!/usr/bin/env bash
# Robi zrzuty menu, modelu innego gracza i widoku z pierwszej osoby.
cd "$(dirname "$0")/.."
G="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
W="$(cygpath -m "$PWD/tools/logs")"; L=tools/logs; P="${1:-7910}"
timeout 34 "$G" --path . --headless -- --server --port=$P > $L/s.log 2>&1 &
sleep 2
timeout 32 "$G" --path . --headless -- --connect=127.0.0.1 --port=$P --name=Cel --bot=runner > $L/r.log 2>&1 &
sleep 1
timeout 12 "$G" --path . --resolution 1280x720 -- --connect=127.0.0.1 --port=$P --name=Widz --tool=res://tools/screenshot.gd --shot="$W/model.png" --shot-after=6 --shot-model > $L/c1.log 2>&1
timeout 14 "$G" --path . --resolution 1280x720 -- --connect=127.0.0.1 --port=$P --name=Strzelec --bot=shooter --tool=res://tools/screenshot.gd --shot="$W/game.png" --shot-after=8 > $L/c.log 2>&1
timeout 10 "$G" --path . --resolution 1280x720 -- --tool=res://tools/screenshot.gd --shot="$W/menu.png" --shot-after=2 > $L/m.log 2>&1
grep -hE "SCRIPT ERROR|^ERROR|^WARNING|\[test\]" $L/c.log $L/c1.log $L/s.log $L/m.log | grep -vE "unref|Unreferenced|Paged|RID alloc|Thread|Leaked" | cut -c1-170 | sort | uniq -c | sort -rn | head -20
