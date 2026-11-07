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
## Trafienie w glowe ma wiekszy znacznik z kolkiem.
var _headshot := false


func flash_hit(killed: bool, headshot := false) -> void:
	_hit = 1.0
	_hit_color = UiStyle.CORAL if killed else (Color("ffcb47") if headshot else Color.WHITE)
	_headshot = headshot
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
	var grow := 1.35 if _headshot else 1.0
	for sign_x: float in [-1.0, 1.0]:
		for sign_y: float in [-1.0, 1.0]:
			var dir := Vector2(sign_x, sign_y)
			draw_line(center + dir * 11.0 * grow, center + dir * 21.0 * grow, Color(OUTLINE, _hit), 6.0, true)
			draw_line(center + dir * 12.0 * grow, center + dir * 20.0 * grow, Color(_hit_color, _hit), 3.0, true)
	if _headshot:
		draw_arc(center, 9.0, 0.0, TAU, 24, Color(OUTLINE, _hit), 5.0, true)
		draw_arc(center, 9.0, 0.0, TAU, 24, Color(_hit_color, _hit), 2.5, true)
