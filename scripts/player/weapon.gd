class_name Weapon
extends Node
## Jedyna bron w grze: blaster z magazynkiem. Lokalny strzal widac od razu, a o trafieniu
## i obrazeniach decyduje wylacznie serwer.

signal fired
signal reload_started
signal reload_cancelled

## Granica cofania czasu, zeby gracz z bardzo slabym laczem nie trafial "przez sciany".
const MAX_REWIND_SECONDS := 0.3

# Stan rollbacku, przewidywany przez wlasciciela.
var last_fire := -1000
var ammo := Weapon.stats().magazine
var reload_end := -1

var _resolved_up_to := -1
var _shown_fire := -1000
var _shown_reload_end := -1

@onready var player := get_parent() as Player
@onready var input := player.get_node("Input") as PlayerInput


func _ready() -> void:
	NetworkTime.after_tick_loop.connect(_after_tick_loop)


static func stats() -> WeaponStats:
	var registry: Node = Engine.get_main_loop().root.get_node("ItemRegistry")
	return registry.weapon_stats(registry.DEFAULT_WEAPON, Rarity.Tier.COMMON)


func is_reloading() -> bool:
	return reload_end >= 0


func refill() -> void:
	ammo = Weapon.stats().magazine
	reload_end = -1


func _rollback_tick(_delta: float, tick: int, _is_fresh: bool) -> void:
	var dead := player.is_dead_at(tick)
	if dead or player.sprinting:
		# Smierc i sprint przerywaja przeladowanie bez uzupelniania amunicji.
		reload_end = -1
	elif reload_end >= 0 and tick >= reload_end:
		refill()
	if dead or player.sprinting:
		return
	if reload_end < 0 and ammo < Weapon.stats().magazine and (input.reload or (ammo == 0 and input.fire)):
		reload_end = tick + NetworkTime.seconds_to_ticks(Weapon.stats().reload_seconds)
	if not input.fire or reload_end >= 0 or ammo <= 0:
		return
	if tick - last_fire < Weapon.stats().fire_interval_ticks:
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
		var damage: int = Weapon.stats().headshot_damage if hit.headshot else Weapon.stats().damage
		GameState.server_damage(victim.peer_id, damage, player.peer_id)


func _after_tick_loop() -> void:
	if last_fire > _shown_fire:
		_shown_fire = last_fire
		fired.emit()
	if reload_end != _shown_reload_end:
		if reload_end >= 0:
			reload_started.emit()
		elif ammo < Weapon.stats().magazine:
			reload_cancelled.emit()
		_shown_reload_end = reload_end
