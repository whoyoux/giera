extends Node
## Dzwieki interfejsu w jednym miejscu: glosnosc, zabezpieczenia przed zalewem tykniec i odtwarzacze.

signal played(cue: Sfx.UiCue)

## Glosnosci sa stopniowane wedlug tego, jak czesto dzwiek pada: im czesciej, tym ciszej.
const LEVELS_DB := {
	Sfx.UiCue.HOVER: -24.0,
	Sfx.UiCue.PRESS: -15.0,
	Sfx.UiCue.CONFIRM: -10.0,
	Sfx.UiCue.BACK: -10.0,
	Sfx.UiCue.TOGGLE_ON: -14.0,
	Sfx.UiCue.TOGGLE_OFF: -14.0,
	Sfx.UiCue.SLIDER: -18.0,
	Sfx.UiCue.OPEN: -14.0,
	Sfx.UiCue.CLOSE: -14.0,
	Sfx.UiCue.ERROR: -9.0,
	Sfx.UiCue.NOTE: -15.0,
	Sfx.UiCue.SWITCH: -10.0,
}
## Dwa tykniecia blizej siebie zlewaja sie w terkot, gdy kursor szybko przejezdza po liscie.
const HOVER_GAP_MS := 45
const SLIDER_GAP_MS := 60
## Lekka zmiana wysokosci, zeby powtarzany dzwiek nie brzmial jak automat.
const HOVER_PITCH_SPREAD := 0.04
const SLIDER_LOW_PITCH := 0.8
const SLIDER_HIGH_PITCH := 1.5
## Okno, ktore sie otwiera lub znika, samo odslania przyciski pod kursorem. To nie gest gracza.
const AFTER_PANEL_QUIET_MS := 150
const AFTER_START_QUIET_MS := 400

var _players := {}
var _next_hover_ms := 0
var _next_slider_ms := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_next_hover_ms = Time.get_ticks_msec() + AFTER_START_QUIET_MS
	# Generujemy od razu, zeby pierwsze najechanie nie przycielo klatki.
	var streams := {
		Sfx.UiCue.HOVER: Sfx.ui_hover(),
		Sfx.UiCue.PRESS: Sfx.ui_press(),
		Sfx.UiCue.CONFIRM: Sfx.ui_confirm(),
		Sfx.UiCue.BACK: Sfx.ui_back(),
		Sfx.UiCue.TOGGLE_ON: Sfx.ui_toggle_on(),
		Sfx.UiCue.TOGGLE_OFF: Sfx.ui_toggle_off(),
		Sfx.UiCue.SLIDER: Sfx.ui_slider(),
		Sfx.UiCue.OPEN: Sfx.ui_open(),
		Sfx.UiCue.CLOSE: Sfx.ui_close(),
		Sfx.UiCue.ERROR: Sfx.ui_error(),
		Sfx.UiCue.NOTE: Sfx.ui_note(),
		Sfx.UiCue.SWITCH: Sfx.switch_item(),
	}
	for cue: Sfx.UiCue in streams:
		var player := AudioStreamPlayer.new()
		player.stream = streams[cue]
		player.max_polyphony = 2
		add_child(player)
		_players[cue] = player


func play(cue: Sfx.UiCue, pitch := 1.0) -> void:
	if cue == Sfx.UiCue.OPEN or cue == Sfx.UiCue.CLOSE:
		_next_hover_ms = maxi(_next_hover_ms, Time.get_ticks_msec() + AFTER_PANEL_QUIET_MS)
	var volume: float = Settings.value("ui_sounds")
	if volume <= 0.001 or not _players.has(cue):
		return
	var player: AudioStreamPlayer = _players[cue]
	player.volume_db = LEVELS_DB[cue] + linear_to_db(volume)
	player.pitch_scale = pitch
	player.play()
	played.emit(cue)


## Tyka tylko po prawdziwym ruchu: nie w czasie przeciagania i nie gdy kursor jest schowany.
func can_hover() -> bool:
	return Time.get_ticks_msec() >= _next_hover_ms \
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE \
		and Input.get_mouse_button_mask() == 0


func hover() -> void:
	if not can_hover():
		return
	_next_hover_ms = Time.get_ticks_msec() + HOVER_GAP_MS
	play(Sfx.UiCue.HOVER, 1.0 + randf_range(-HOVER_PITCH_SPREAD, HOVER_PITCH_SPREAD))


## Wysokosc idzie za wartoscia suwaka od 0 do 1.
func slider(ratio: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_slider_ms:
		return
	_next_slider_ms = now + SLIDER_GAP_MS
	play(Sfx.UiCue.SLIDER, lerpf(SLIDER_LOW_PITCH, SLIDER_HIGH_PITCH, clampf(ratio, 0.0, 1.0)))
