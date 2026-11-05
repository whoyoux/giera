#!/usr/bin/env bash
# Test tancow przez siec: bot z opoznieniem tanczy po kolei i co chwile sie rusza. Serwer, on sam
# i drugi klient musza zobaczyc te same tance, a ruch musi kazdy z nich przerwac.
# Uzycie: tools/dance_net_test.sh [opoznienie_ms] [strata_procent] [zrzut.png]
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
DELAY="${1:-120}"
LOSS="${2:-3}"
SHOT="${3:-}"
SERVER_PORT=7963
PROXY_PORT=7964
LOGS=tools/logs
PROBE=--tool=res://tools/dance_probe.gd
SECONDS_PLAYED=38
mkdir -p "$LOGS"

timeout $((SECONDS_PLAYED + 8)) "$GODOT" --path . --headless -- --server --port=$SERVER_PORT $PROBE > "$LOGS/dance_server.log" 2>&1 &
sleep 2
python tools/lag_proxy.py $PROXY_PORT $SERVER_PORT "$DELAY" "$LOSS" $((SECONDS_PLAYED + 6)) > /dev/null 2>&1 &
sleep 1
timeout $((SECONDS_PLAYED + 4)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Tancerz --bot=dancer --bot-seconds=$SECONDS_PLAYED $PROBE > "$LOGS/dance_bot.log" 2>&1 &
if [ -n "$SHOT" ]; then
	sleep 8
	timeout 20 "$GODOT" --path . --resolution 1280x720 -- --settings-path=user://t.cfg --connect=127.0.0.1 --port=$SERVER_PORT --name=Widz $PROBE --dance-shot="$SHOT" > "$LOGS/dance_shot.log" 2>&1 &
fi
timeout $((SECONDS_PLAYED + 4)) "$GODOT" --path . --headless -- --connect=127.0.0.1 --port=$PROXY_PORT --name=Widz2 --bot=spectator $PROBE > "$LOGS/dance_watch.log" 2>&1 &
wait

FAILED=0
sequence() { grep '\[dance\] Tancerz' "$1" | awk '{print $3}' | tr '\n' ' '; }
ON_SERVER="$(sequence "$LOGS/dance_server.log")"
ON_BOT="$(sequence "$LOGS/dance_bot.log")"
ON_WATCH="$(sequence "$LOGS/dance_watch.log")"
echo "serwer: $ON_SERVER"
echo "tancerz: $ON_BOT"
echo "widz: $ON_WATCH"
for id in 1 2 3 4 5 6; do
	case " $ON_WATCH " in *" $id "*) ;; *) echo "widz nie zobaczyl tanca $id"; FAILED=1 ;; esac
done
# Kazdy taniec konczy sie zerem, bez przeskoku od razu do nastepnego.
if echo "$ON_WATCH" | grep -qE '(^| )[1-6] [1-6]( |$)'; then
	echo "ruch nie przerwal tanca"
	FAILED=1
fi
# Widz dolacza pozniej, wiec widzi koncowke tego, co serwer.
case "$ON_SERVER" in *"$ON_WATCH") ;; *) echo "serwer i widz widza co innego"; FAILED=1 ;; esac
for name in server bot watch; do
	if grep -q 'SCRIPT ERROR' "$LOGS/dance_$name.log"; then
		grep 'SCRIPT ERROR' "$LOGS/dance_$name.log" | cut -c1-150 | sort | uniq -c | head -5
		FAILED=1
	fi
done
[ "$FAILED" = 0 ] && echo "WSZYSTKO OK" || echo "BLAD"
