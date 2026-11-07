class_name DamageNumbers
extends Node3D
## Liczby obrazen nad trafionym celem. Widzi je tylko atakujacy, a ustawienie pozwala je wylaczyc.
## Trafienie w glowe ma wieksza, zolta liczbe.

const RISE := 0.9
const SECONDS := 0.8


func _ready() -> void:
	GameState.hit_details.connect(_on_hit)


func _on_hit(details: Dictionary) -> void:
	if not Settings.value("show_damage_numbers") or details.get("amount", 0) <= 0:
		return
	var at: Vector3 = details.get("position", Vector3.INF)
	if at == Vector3.INF:
		var victim := GameState.player_node(details.get("victim", 0))
		if victim == null:
			return
		at = victim.position + Vector3.UP * 1.9
	var headshot: bool = details.get("headshot", false)
	var label := Label3D.new()
	label.text = str(details.amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011 if headshot else 0.0008
	label.font_size = 64
	label.outline_size = 14
	label.modulate = Color("ffcb47") if headshot else (UiStyle.CORAL if details.get("killed", false) else Color.WHITE)
	label.outline_modulate = UiStyle.INK
	label.position = at + Vector3(randf_range(-0.2, 0.2), 0.3, randf_range(-0.2, 0.2))
	add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + RISE, SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, SECONDS * 0.5).set_delay(SECONDS * 0.5)
	tween.chain().tween_callback(label.queue_free)
