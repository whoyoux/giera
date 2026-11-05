class_name Weapon
extends Node
## Jedyna bron w grze: blaster z magazynkiem. Lokalny strzal widac od razu, a o trafieniu
## i obrazeniach decyduje wylacznie serwer.

signal fired
signal reload_started

const FIRE_INTERVAL := 0.2
const DAMAGE := 20
const HEADSHOT_DAMAGE := 40
const MAGAZINE := 12
const RELOAD_SECONDS := 1.6
## Granica cofania czasu, zeby gracz z bardzo slabym laczem nie trafial "przez sciany".
const MAX_REWIND_SECONDS := 0.3

# Stan rollbacku, przewidywany przez wlasciciela.
var last_fire := -1000
var ammo := MAGAZINE
var reload_end := -1

var _resolved_up_to := -1
var _shown_fire := -1000
var _shown_reload_end := -1

@onready var player := get_parent() as Player
@onready var input := player.get_node("Input") as PlayerInput


func _ready() -> void:
	NetworkTime.after_tick_loop.connect(_after_tick_loop)


func is_reloading() -> bool:
	return reload_end >= 0


func refill() -> void:
	ammo = MAGAZINE
	reload_end = -1


func _rollback_tick(_delta: float, tick: int, _is_fresh: bool) -> void:
	if reload_end >= 0 and tick >= reload_end:
		refill()
	if player.is_dead_at(tick):
		return
	if reload_end < 0 and ammo < MAGAZINE and (input.reload or (ammo == 0 and input.fire)):
		reload_end = tick + NetworkTime.seconds_to_ticks(RELOAD_SECONDS)
	if not input.fire or player.sprinting or reload_end >= 0 or ammo <= 0:
		return
	if tick - last_fire < NetworkTime.seconds_to_ticks(FIRE_INTERVAL):
		return
	last_fire = tick
	ammo -= 1
	if multiplayer.is_server() and tick > _resolved_up_to:
		# Ten sam tick moze byc symulowany kilka razy, ale rozliczamy go raz.
		_resolved_up_to = tick
		_resolve_shot(tick)


## Klient widzi innych graczy z opoznieniem, wiec serwer cofa ich do chwili, ktora
## strzelec mial na ekranie. Dzieki temu liczy sie to, w co gracz naprawde celowal.
func _resolve_shot(tick: int) -> void:
	var view_tick := -1
	if input.view_tick >= 0:
		view_tick = clampi(input.view_tick, tick - NetworkTime.seconds_to_ticks(MAX_REWIND_SECONDS), tick)
	var hit := Hitscan.trace(player.get_world_3d(), player.eye_position(),
			Hitscan.direction(player.yaw, player.pitch), player.peer_id, get_tree(), view_tick)
	var victim := hit.player as Player
	if victim != null:
		var damage: int = HEADSHOT_DAMAGE if hit.headshot else DAMAGE
		GameState.server_damage(victim.peer_id, damage, player.peer_id)


func _after_tick_loop() -> void:
	if last_fire > _shown_fire:
		_shown_fire = last_fire
		fired.emit()
	if reload_end != _shown_reload_end:
		if reload_end >= 0:
			reload_started.emit()
		_shown_reload_end = reload_end
