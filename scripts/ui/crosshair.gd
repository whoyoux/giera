class_name Crosshair
extends Control
## Celownik rozszerzajacy sie przy strzale i znacznik trafienia.

const OUTLINE := Color(0.18, 0.15, 0.25, 0.75)
const LINE_WIDTH := 2.5
const DOT_RADIUS := 1.5
## O tyle obwodka wystaje poza kreske z kazdej strony.
const OUTLINE_PAD := 1.2

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
## Kolor druzyny, gdy celownik stoi na sojuszniku. Przezroczysty, gdy nie stoi.
var ally_color := Color.TRANSPARENT


## Kolory znacznika odpowiadaja dzwiekom: zwykle trafienie, w glowe, zabojstwo, zabojstwo w glowe
## i zabojstwo z AWP, ktore ma wlasny dzwonek.
const HIT_COLORS := {
	"hit": Color.WHITE,
	"headshot": Color("ffcb47"),
	"kill": UiStyle.CORAL,
	"kill_headshot": Color("ff4fa3"),
	"sniper": Color("7fd3ff"),
}


func flash_hit(killed: bool, headshot := false) -> void:
	flash_kind(hit_kind(killed, headshot, false))


## Rodzaj trafienia do dzwieku i koloru znacznika.
static func hit_kind(killed: bool, headshot: bool, sniper: bool) -> String:
	if killed and sniper:
		return "sniper"
	if killed:
		return "kill_headshot" if headshot else "kill"
	return "headshot" if headshot else "hit"


func flash_kind(kind: String) -> void:
	_hit = 1.0
	_hit_color = HIT_COLORS.get(kind, Color.WHITE)
	_headshot = kind in ["headshot", "kill_headshot", "sniper"]
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
		var length_scale: float = Settings.value("crosshair_size")
		var width_scale: float = Settings.value("crosshair_thickness")
		var outlined: bool = Settings.value("crosshair_outline")
		# Bez pokazywania rozrzutu celownik ma staly rozmiar i nie rozszerza sie przy strzale.
		var dynamic: bool = Settings.value("crosshair_spread")
		var gap := lerpf(7.0, 3.5, _aim)
		if dynamic:
			gap = maxf(gap, _shown_radius) + _spread * lerpf(7.0, 3.0, _aim)
		var length := lerpf(8.0, 5.0, _aim) * length_scale
		# Na sojuszniku celownik bierze kolor jego druzyny, a srodek znika, zeby nie kusil do strzalu.
		var ally := ally_color.a > 0.0
		var color := ally_color if ally else Settings.crosshair_color()
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			if outlined:
				draw_line(center + dir * (gap - OUTLINE_PAD), center + dir * (gap + length + OUTLINE_PAD), OUTLINE, LINE_WIDTH * width_scale + OUTLINE_PAD * 2.0, true)
			draw_line(center + dir * gap, center + dir * (gap + length), color, LINE_WIDTH * width_scale, true)
		if not ally and Settings.value("crosshair_dot"):
			if outlined:
				draw_circle(center, DOT_RADIUS * width_scale + OUTLINE_PAD, OUTLINE, true, -1.0, true)
			draw_circle(center, DOT_RADIUS * width_scale, color, true, -1.0, true)
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
