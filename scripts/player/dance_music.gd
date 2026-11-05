class_name DanceMusic
extends Node3D
## Muzyka tanca jednego gracza. Wlasna gra rowno, a cudza dobiega z miejsca tancerza.

const MUSIC_DB := -7.0
const SILENT_DB := -60.0
const FADE_SECONDS := 0.3
const REACH := 32.0
const UNIT_SIZE := 7.0
const HEIGHT := 1.2

## AudioStreamPlayer albo AudioStreamPlayer3D. Maja te same pola, ale nie wspolna klase.
var _audio: Node
var _fade := 0.0
var _stopping := false


func setup(local: bool) -> void:
	position.y = HEIGHT
	if local:
		_audio = AudioStreamPlayer.new()
	else:
		var positional := AudioStreamPlayer3D.new()
		positional.max_distance = REACH
		positional.unit_size = UNIT_SIZE
		_audio = positional
	add_child(_audio)
	set_process(false)


func play(stream: AudioStream) -> void:
	_audio.set("stream", stream)
	_audio.call("play")
	_fade = 1.0
	_stopping = false
	_apply_volume()
	set_process(true)


func stop() -> void:
	_stopping = true


func is_playing() -> bool:
	return _audio != null and _audio.get("playing")


func stream() -> AudioStream:
	return _audio.get("stream")


func volume_db() -> float:
	return _audio.get("volume_db")


func _process(delta: float) -> void:
	if _stopping:
		_fade = move_toward(_fade, 0.0, delta / FADE_SECONDS)
		if _fade <= 0.0:
			_audio.call("stop")
			set_process(false)
			return
	_apply_volume()


func _apply_volume() -> void:
	var level := _fade * float(Settings.value("dance_music"))
	_audio.set("volume_db", MUSIC_DB + linear_to_db(level) if level > 0.001 else SILENT_DB)
