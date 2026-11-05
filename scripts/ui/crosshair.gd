class_name Crosshair
extends Control
## Celownik i znacznik trafienia rysowane w kodzie.

var _hit := 0.0
var _hit_color := Color.WHITE


func flash_hit(killed: bool) -> void:
	_hit = 1.0
	_hit_color = UiStyle.DANGER if killed else Color.WHITE
	queue_redraw()


func _process(delta: float) -> void:
	if _hit > 0.0:
		_hit = maxf(0.0, _hit - delta * 4.0)
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 4.5, UiStyle.INK)
	draw_circle(center, 2.5, Color.WHITE)
	if _hit <= 0.0:
		return
	var color := Color(_hit_color, _hit)
	for sign_x: float in [-1.0, 1.0]:
		for sign_y: float in [-1.0, 1.0]:
			var direction := Vector2(sign_x, sign_y)
			draw_line(center + direction * 9.0, center + direction * 18.0, Color(UiStyle.INK, _hit), 6.0)
			draw_line(center + direction * 10.0, center + direction * 17.0, color, 3.0)
