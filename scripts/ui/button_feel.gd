class_name ButtonFeel
extends Node
## Ozywia przycisk: rosnie pod kursorem, wciska sie przy kliknieciu i odpowiada dzwiekiem.
## Wszystkie stany przechodza przez jedno miejsce, wiec szybkie ruchy kursora nie zostawiaja
## przycisku przekrzywionego.

const HOVER_SCALE := 1.035
const PRESS_SCALE := 0.95
const HOVER_TILT_DEGREES := -1.2
const PRESS_SECONDS := 0.05
const SETTLE_SECONDS := 0.14

var _button: BaseButton
var _sound: Sfx.UiCue
var _tilt: float
var _hovered := false
var _held := false
var _tween: Tween


## Przelacznik sam wybiera dzwiek wlaczenia lub wylaczenia, wiec przekazuje sie mu NONE.
static func attach(button: BaseButton, sound := Sfx.UiCue.CONFIRM, tilts := true) -> ButtonFeel:
	var feel := ButtonFeel.new()
	feel.name = "Feel"
	feel._button = button
	feel._sound = sound
	feel._tilt = HOVER_TILT_DEGREES if tilts else 0.0
	button.add_child(feel)
	return feel


func _ready() -> void:
	_button.pivot_offset_ratio = Vector2(0.5, 0.5)
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	_button.focus_entered.connect(_on_focus_entered)
	_button.focus_exited.connect(_settle)
	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)
	_button.pressed.connect(_on_pressed)
	_button.visibility_changed.connect(_on_visibility_changed)


func _on_mouse_entered() -> void:
	_hovered = true
	if not _button.disabled:
		UiSound.hover()
	_settle()


func _on_mouse_exited() -> void:
	_hovered = false
	_settle()


## Tylko klawiatura: fokus po kliknieciu mysza jest ukryty i nie ma po co tykac.
func _on_focus_entered() -> void:
	if _button.has_focus(true):
		UiSound.hover()
	_settle()


func _on_button_down() -> void:
	_held = true
	UiSound.play(Sfx.UiCue.PRESS)
	_settle()


func _on_button_up() -> void:
	_held = false
	# Klikniecie moglo wlasnie wylaczyc przycisk, wiec patrzymy na stan po jego obsluzeniu.
	_settle.call_deferred()


func _on_pressed() -> void:
	if _button.toggle_mode:
		UiSound.play(Sfx.UiCue.TOGGLE_ON if _button.button_pressed else Sfx.UiCue.TOGGLE_OFF)
	else:
		UiSound.play(_sound)


## Ukryty przycisk nie dostanie mouse_exited, a po powrocie nie moze stac powiekszony.
func _on_visibility_changed() -> void:
	if _button.is_visible_in_tree():
		return
	_hovered = false
	_held = false
	if _tween != null:
		_tween.kill()
	_button.scale = Vector2.ONE
	_button.rotation_degrees = 0.0


func _settle() -> void:
	if not is_inside_tree() or not _button.is_visible_in_tree():
		return
	var lit := not _button.disabled and (_hovered or _button.has_focus(true))
	var target := PRESS_SCALE if _held else (HOVER_SCALE if lit else 1.0)
	var tilt := _tilt if lit and not _held else 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel()
	if _held:
		_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var seconds := PRESS_SECONDS if _held else SETTLE_SECONDS
	_tween.tween_property(_button, "scale", Vector2.ONE * target, seconds)
	_tween.tween_property(_button, "rotation_degrees", tilt, seconds)
