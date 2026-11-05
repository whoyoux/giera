class_name Crosshair
extends Control
## Celownik rozszerzajacy sie przy strzale i znacznik trafienia.

const OUTLINE := Color(0.18, 0.15, 0.25, 0.75)

var _hit := 0.0
var _hit_color := Color.WHITE
var _spread := 0.0
var hidden_for_sprint := false
## Przy celowaniu celownik sie zaciska.
var aiming := false
var _aim := 0.0
## Promien rozrzutu broni na ekranie, w pikselach. Zero oznacza zwykly celownik.
var spread_radius := 0.0
var _shown_radius := 0.0


func flash_hit(killed: bool) -> void:
	_hit = 1.0
	_hit_color = UiStyle.CORAL if killed else Color.WHITE
	queue_redraw()


func kick() -> void:
	_spread = 1.0


func _process(delta: float) -> void:
	_hit = maxf(0.0, _hit - delta * 4.0)
	_spread = maxf(0.0, _spread - delta * 6.0)
	_aim = move_toward(_aim, 1.0 if aiming else 0.0, delta * 8.0)
	_shown_radius = lerpf(_shown_radius, spread_radius, minf(delta * 14.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var center := (size * 0.5).round()
	if not hidden_for_sprint:
		var gap := maxf(lerpf(7.0, 3.5, _aim), _shown_radius) + _spread * lerpf(7.0, 3.0, _aim)
		var length := lerpf(8.0, 5.0, _aim)
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(center + dir * gap, center + dir * (gap + length), OUTLINE, 5.0, true)
			draw_line(center + dir * gap, center + dir * (gap + length), Color.WHITE, 2.5, true)
		draw_circle(center, 2.6, OUTLINE, true, -1.0, true)
		draw_circle(center, 1.5, Color.WHITE, true, -1.0, true)
	if _hit <= 0.0:
		return
	for sign_x: float in [-1.0, 1.0]:
		for sign_y: float in [-1.0, 1.0]:
			var dir := Vector2(sign_x, sign_y)
			draw_line(center + dir * 11.0, center + dir * 21.0, Color(OUTLINE, _hit), 6.0, true)
			draw_line(center + dir * 12.0, center + dir * 20.0, Color(_hit_color, _hit), 3.0, true)
