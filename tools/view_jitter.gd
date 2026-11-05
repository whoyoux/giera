extends Node
## Narzedzie testowe: mierzy szarpanie broni wzgledem kamery nakladki podczas biegu.
## Uzycie z oknem gry i --bot=runner: -- --tool=res://tools/view_jitter.gd

var _view: ViewModel
var _last := Vector3.ZERO
var _last_step := Vector3.ZERO
var _worst := 0.0
var _sum := 0.0
var _frames := 0


func _ready() -> void:
	process_priority = 1000
	get_tree().create_timer(14.0).timeout.connect(_finish)


func _process(_delta: float) -> void:
	if _view == null:
		for node in get_tree().get_nodes_in_group(&"players"):
			if (node as Player).is_local() and node.input.move != Vector2.ZERO:
				_view = (node as Player).view_model
		return
	var now: Vector3 = _view.overlay_camera().to_local(_view.muzzle_position())
	var step := now - _last
	# Zmiana kroku wychwytuje szarpniecia, a pomija plynne kolysanie.
	var jerk := (step - _last_step).length()
	_last = now
	_last_step = step
	if _frames > 5:
		_worst = maxf(_worst, jerk)
		_sum += jerk
	_frames += 1


func _finish() -> void:
	print("[jitter] klatki=%d srednie_szarpniecie=%.2f mm najwieksze=%.1f mm" % [_frames, 1000.0 * _sum / maxi(_frames, 1), 1000.0 * _worst])
	get_tree().quit()
