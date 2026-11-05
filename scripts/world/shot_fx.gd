class_name ShotFx
extends RefCounted
## Krotkotrwale efekty strzalu. Czysto wizualne, nie wplywaja na rozgrywke.


static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var node := MeshInstance3D.new()
	node.mesh = LowPoly.box(Vector3(0.05, 0.05, length))
	node.material_override = LowPoly.glow(Color("fff3a3"))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.98 else Vector3.RIGHT
	node.look_at_from_position((from + to) * 0.5, to, up)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3(0.0, 0.0, 1.0), 0.09)
	tween.tween_callback(node.queue_free)


static func impact(parent: Node, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.mesh = LowPoly.ball(0.16, 5, 2)
	node.material_override = LowPoly.glow(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.global_position = at
	node.scale = Vector3.ONE * 0.5
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 1.5, 0.07)
	tween.tween_property(node, "scale", Vector3.ZERO, 0.1)
	tween.tween_callback(node.queue_free)
