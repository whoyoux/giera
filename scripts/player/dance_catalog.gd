class_name DanceCatalog
extends RefCounted
## Spis tancow. Numer na liscie plus jeden idzie przez siec, a zero oznacza brak tanca,
## wiec nowy taniec dopisuj na koncu. Ruch tanca jest w DanceClips, a muzyka w assets/music/dances.
## Utwory tworzy tools/generate_dance_music.py. Tempo musi sie tam zgadzac.

const NONE := 0
const DANCES: Array[Dictionary] = [
	{ "key": "bujanka", "name": "Bujanka", "bpm": 100.0, "beats": 8, "color": Color("5b8def") },
	{ "key": "robot", "name": "Robot", "bpm": 112.0, "beats": 8, "color": Color("2ec4b6") },
	{ "key": "wiatrak", "name": "Wiatrak", "bpm": 126.0, "beats": 8, "color": Color("f9a03f") },
	{ "key": "podskoki", "name": "Podskoki", "bpm": 132.0, "beats": 8, "color": Color("ef6f6c") },
	{ "key": "skretas", "name": "Skrętas", "bpm": 120.0, "beats": 4, "color": Color("9b7bff") },
	{ "key": "piruet", "name": "Piruet", "bpm": 92.0, "beats": 8, "color": Color("f9c74f") },
]


static func is_valid(id: int) -> bool:
	return id > 0 and id <= DANCES.size()


static func entry(id: int) -> Dictionary:
	return DANCES[id - 1]


## Klip w AnimationPlayerze postaci.
static func clip_of(id: int) -> String:
	return "%s/%s" % [DanceClips.LIBRARY, entry(id).key]


## Zapetlony utwor tanca.
static func music_of(id: int) -> AudioStream:
	var wav := load("res://assets/music/dances/%s.wav" % entry(id).key) as AudioStreamWAV
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	return wav
