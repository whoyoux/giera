extends Node
## Test bufora ruchu innych graczy: przerwa w danych nie moze dac przeskoku.
## Uzycie: godot --headless --path . -- --tool=res://tools/remote_motion_test.gd

const FRAME := 1.0 / 60.0
const FRAME_PER_TICK := 1.0
## Tyle metrow bot przebiega w ticku.
const STEP := 0.15

var _failures := 0


func _ready() -> void:
	_test_steady()
	_test_gap()
	_test_teleport()
	_test_slow_player()
	_test_buffer()
	print("[test] %s" % ("WSZYSTKO OK" if _failures == 0 else "BLEDY: %d" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _test_steady() -> void:
	var motion := RemoteMotion.new()
	var biggest := _run(motion, 0, 240, -1, -1)
	_check("rowne stany daja rowny ruch", biggest <= STEP / FRAME_PER_TICK * 1.5)


## Gracz nie wysyla nic przez 233 ms, a potem wszystko dochodzi naraz.
func _test_gap() -> void:
	var motion := RemoteMotion.new()
	var biggest := _run(motion, 0, 400, 120, 134)
	_check("po przerwie nie ma przeskoku (%.2f m na klatke)" % biggest, biggest <= STEP / FRAME_PER_TICK * 2.0)


func _test_teleport() -> void:
	var motion := RemoteMotion.new()
	motion.add_sample(0, Vector3.ZERO, 0.0, 0.0)
	motion.add_sample(1, Vector3(40, 0, 0), 0.0, 0.0)
	motion.advance(FRAME, 0.5)
	_check("przed odrodzeniem stoi w starym miejscu", motion.shown_position == Vector3.ZERO)
	motion.advance(FRAME, 1.5)
	_check("odrodzenie nie jest wygladzane", motion.shown_position == Vector3(40, 0, 0))


## Jeden gracz z duzym lagiem nie opoznia zegara bardziej niz o LAG_SPREAD_TICKS ponad mediane.
func _test_slow_player() -> void:
	var fast_a := _with_ages(2.0, 0.0)
	var fast_b := _with_ages(2.0, 0.0)
	var slow := _with_ages(12.0, 0.0)
	var lag := RemoteMotion.lag_for([fast_a, fast_b, slow] as Array[RemoteMotion])
	_check("wolny gracz opoznia najwyzej o %.0f tickow (%.1f)" % [RemoteMotion.LAG_SPREAD_TICKS, lag], lag <= 2.0 + RemoteMotion.LAG_SPREAD_TICKS + RemoteMotion.MAX_BUFFER_TICKS)
	var alone := RemoteMotion.lag_for([slow] as Array[RemoteMotion])
	_check("jedyny gracz z lagiem jest pokazywany bez przeskokow (%.1f)" % alone, alone >= 12.0 + RemoteMotion.MIN_BUFFER_TICKS)


## Na rownym laczu zapas pokrywa jeden tick odstepu, po zgubionym pakiecie dwa, a na nierownym
## rosnie, ale nie ponad granice.
func _test_buffer() -> void:
	var steady := RemoteMotion.lag_for([_with_ages(2.0, 0.0)] as Array[RemoteMotion])
	_check("rowne lacze ma maly zapas (%.2f)" % steady, is_equal_approx(steady, 2.0 + 1.0 + RemoteMotion.CLOCK_MARGIN_TICKS))
	var lossy := RemoteMotion.lag_for([_with_ages(2.0, 0.0, 2)] as Array[RemoteMotion])
	_check("zgubiony pakiet powieksza zapas o tick (%.2f)" % lossy, is_equal_approx(lossy, 2.0 + minf(2.0 + RemoteMotion.CLOCK_MARGIN_TICKS, RemoteMotion.MAX_BUFFER_TICKS)))
	var shaky := RemoteMotion.lag_for([_with_ages(2.0, 10.0)] as Array[RemoteMotion])
	_check("nierowne lacze ma najwiekszy zapas (%.2f)" % shaky, is_equal_approx(shaky, 2.0 + RemoteMotion.MAX_BUFFER_TICKS))


## Bufor z wiekiem stanow od "base" do "base + spread" i jednym odstepem "gap" miedzy stanami.
func _with_ages(base: float, spread: float, gap := 1) -> RemoteMotion:
	var motion := RemoteMotion.new()
	for index in RemoteMotion.AGE_WINDOW:
		motion._ages.append(base + spread * index / RemoteMotion.AGE_WINDOW)
		motion._gaps.append(gap if index == 0 else 1)
	motion._buffer = motion.needed_buffer()
	return motion


## Stany dochodza 6 tickow po czasie, a te z przerwy dopiero po niej.
func _run(motion: RemoteMotion, first: int, last: int, gap_from: int, gap_to: int) -> float:
	var biggest := 0.0
	var previous := Vector3.ZERO
	var started := false
	var frames := int((last - first) * FRAME_PER_TICK)
	for frame in frames:
		var clock := first + frame / FRAME_PER_TICK
		var arrived := int(clock) - 6
		if arrived >= gap_from and arrived < gap_to:
			arrived = gap_from - 1
		for tick in range(motion.newest_tick + 1, arrived + 1):
			motion.add_sample(tick, Vector3(tick * STEP, 0, 0), 0.0, 0.0)
		motion.advance(FRAME, clock - 12.0)
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
