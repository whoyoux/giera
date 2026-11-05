class_name DamageIndicator
extends Control
## Luki wokol celownika pokazujace, z ktorej strony padl strzal.

const LIFETIME := 1.1
const RADIUS := 150.0
const HALF_WIDTH := 0.42

var _player: Player
var _marks: Array[Dictionary] = []


func bind(player: Player) -> void:
	_player = player
	_marks.clear()


func add_hit(source: Vector3) -> void:
	_marks.append({ "source": source, "life": LIFETIME })


func _process(delta: float) -> void:
	for mark in _marks:
		mark.life -= delta
	_marks = _marks.filter(func(mark: Dictionary) -> bool: return mark.life > 0.0)
	queue_redraw()


func _draw() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var center := size * 0.5
	for mark in _marks:
		var to_source: Vector3 = mark.source - _player.position
		var local := to_source.rotated(Vector3.UP, -_player.input.look_yaw)
		# Rysowanie liczy kat od osi X, a 0 ma oznaczac kierunek "przed graczem".
		var angle := atan2(local.x, -local.z) - PI * 0.5
		var strength := clampf(mark.life / LIFETIME * 1.6, 0.0, 1.0)
		draw_arc(center, RADIUS, angle - HALF_WIDTH, angle + HALF_WIDTH, 24, Color(UiStyle.INK, 0.55 * strength), 15.0, true)
		draw_arc(center, RADIUS, angle - HALF_WIDTH, angle + HALF_WIDTH, 24, Color(UiStyle.CORAL, strength), 10.0, true)
