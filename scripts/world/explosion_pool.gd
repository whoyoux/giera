class_name ExplosionPool
extends Node3D
## Gotowe wybuchy. Utworzenie czasteczek zajmuje ponad 100 ms, co przycieloby gre w chwili
## eksplozji, wiec powstaja raz przy starcie, a potem sa tylko przenoszone i uruchamiane.

const POOL_SIZE := 4
const WARMUP_SECONDS := 0.15
const WARMUP_DISTANCE := 3.0
const WARMUP_SCALE := 0.001

static var instance: ExplosionPool

var _entries: Array[Dictionary] = []
var _next := 0
var _warmed := false


func _ready() -> void:
	instance = self
	for i in POOL_SIZE:
		var root := Node3D.new()
		root.visible = false
		add_child(root)
		_entries.append({ "root": root, "parts": GrenadeFx.build(root), "ends_at": 0 })


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for entry in _entries:
		if entry.root.visible and now >= entry.ends_at:
			entry.root.visible = false


func play(at: Vector3) -> void:
	var entry := _entries[_next]
	_next = (_next + 1) % _entries.size()
	var root: Node3D = entry.root
	root.scale = Vector3.ONE
	root.global_position = at
	root.visible = true
	entry.ends_at = Time.get_ticks_msec() + int(GrenadeFx.LIFETIME_SECONDS * 1000.0)
	GrenadeFx.fire(entry.parts)
	GrenadeFx.add_scorch(get_parent(), at)


func active_count() -> int:
	return _entries.filter(func(entry: Dictionary) -> bool: return entry.root.visible).size()


## Karta graficzna przygotowuje shadery przy pierwszym rysowaniu, co tez trwa. Niewidoczny,
## malutki wybuch przed kamera zalatwia to, zanim gracz zacznie grac.
func warm_up(camera: Camera3D) -> void:
	if _warmed:
		return
	_warmed = true
	var entry := _entries[0]
	var root: Node3D = entry.root
	root.scale = Vector3.ONE * WARMUP_SCALE
	root.global_position = camera.global_position - camera.global_basis.z * WARMUP_DISTANCE
	root.visible = true
	for particles: CPUParticles3D in entry.parts.particles:
		particles.restart()
	entry.parts.ball.scale = Vector3.ONE
	entry.parts.ring.scale = Vector3.ONE
	await get_tree().create_timer(WARMUP_SECONDS).timeout
	for particles: CPUParticles3D in entry.parts.particles:
		particles.emitting = false
	entry.parts.ball.scale = Vector3.ZERO
	entry.parts.ring.scale = Vector3.ZERO
	root.visible = false
	root.scale = Vector3.ONE
