extends Node
## Test bufora ruchu innych graczy: przerwa w danych nie moze dac przeskoku.
## Uzycie: godot --headless --path . -- --tool=res://tools/remote_motion_test.gd

const FRAME := 1.0 / 60.0
const FRAME_PER_TICK := 2.0
## Tyle metrow bot przebiega w ticku.
const STEP := 0.3

var _failures := 0


func _ready() -> void:
	_test_steady()
	_test_gap()
	_test_teleport()
	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _test_steady() -> void:
	var motion := RemoteMotion.new()
	var biggest := _run(motion, 0, 120, -1, -1)
	_check("rowne stany daja rowny ruch", biggest <= STEP * 0.75)


## Gracz nie wysyla nic przez 233 ms, a potem wszystko dochodzi naraz.
func _test_gap() -> void:
	var motion := RemoteMotion.new()
	var biggest := _run(motion, 0, 200, 60, 67)
	_check("po przerwie nie ma przeskoku (%.2f m na klatke)" % biggest, biggest <= STEP * 1.0)


func _test_teleport() -> void:
	var motion := RemoteMotion.new()
	motion.add_sample(0, Vector3.ZERO, 0.0, 0.0)
	motion.add_sample(1, Vector3(40, 0, 0), 0.0, 0.0)
	motion.advance(FRAME, 0.5)
	_check("przed odrodzeniem stoi w starym miejscu", motion.shown_position == Vector3.ZERO)
	motion.advance(FRAME, 1.5)
	_check("odrodzenie nie jest wygladzane", motion.shown_position == Vector3(40, 0, 0))


## Stany dochodza 3 ticki po czasie, a te z przerwy dopiero po niej.
func _run(motion: RemoteMotion, first: int, last: int, gap_from: int, gap_to: int) -> float:
	var biggest := 0.0
	var previous := Vector3.ZERO
	var started := false
	var frames := int((last - first) * FRAME_PER_TICK)
	for frame in frames:
		var clock := first + frame / FRAME_PER_TICK
		var arrived := int(clock) - 3
		if arrived >= gap_from and arrived < gap_to:
			arrived = gap_from - 1
		for tick in range(motion.newest_tick + 1, arrived + 1):
			motion.add_sample(tick, Vector3(tick * STEP, 0, 0), 0.0, 0.0)
		motion.advance(FRAME, clock - 6.0)
		if motion.has_samples():
			if started:
				biggest = maxf(biggest, motion.shown_position.distance_to(previous))
			previous = motion.shown_position
			started = true
	return biggest


func _check(what: String, ok: bool) -> void:
	print("[test] %s %s" % ["ok " if ok else "BLAD", what])
	if not ok:
		_failures += 1
