class_name Weapon
extends Node
## Jedyna bron w grze: blaster. Lokalny strzal widac od razu, a o trafieniu
## i obrazeniach decyduje wylacznie serwer.

signal fired

const FIRE_INTERVAL := 0.2
const DAMAGE := 20
const HEADSHOT_DAMAGE := 40

## Tick ostatniego strzalu: stan rollbacku, przewidywany przez wlasciciela.
var last_fire := -1000

var _resolved_up_to := -1
var _shown_fire := -1000

@onready var player := get_parent() as Player
@onready var input := player.get_node("Input") as PlayerInput


func _ready() -> void:
	NetworkTime.after_tick_loop.connect(_after_tick_loop)


func _rollback_tick(_delta: float, tick: int, _is_fresh: bool) -> void:
	if not input.fire or player.is_dead_at(tick):
		return
	if tick - last_fire < NetworkTime.seconds_to_ticks(FIRE_INTERVAL):
		return
	last_fire = tick
	if multiplayer.is_server() and tick > _resolved_up_to:
		# Ten sam tick moze byc symulowany kilka razy, ale rozliczamy go raz.
		_resolved_up_to = tick
		_resolve_shot()


func _resolve_shot() -> void:
	var hit := Hitscan.trace(player.get_world_3d(), player.eye_position(),
			Hitscan.direction(player.yaw, player.pitch), player.peer_id, get_tree())
	var victim := hit.player as Player
	if victim != null:
		var damage: int = HEADSHOT_DAMAGE if hit.headshot else DAMAGE
		GameState.server_damage(victim.peer_id, damage, player.peer_id)


func _after_tick_loop() -> void:
	if last_fire > _shown_fire:
		_shown_fire = last_fire
		fired.emit()
