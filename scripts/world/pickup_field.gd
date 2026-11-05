class_name PickupField
extends Node3D
## Pokazuje przedmioty z WorldItems. Istnieje tylko tam, gdzie jest ekran.

var _views := {}


func _ready() -> void:
	WorldItems.item_added.connect(_on_added)
	WorldItems.item_removed.connect(_on_removed)
	WorldItems.items_cleared.connect(_on_cleared)
	for id: int in WorldItems.items:
		_on_added(WorldItems.items[id])


func _process(_delta: float) -> void:
	for id: int in _views:
		(_views[id] as PickupView).set_focused(id == WorldItems.focused_id)


func view_count() -> int:
	return _views.size()


func _on_added(entry: Dictionary) -> void:
	var view := PickupView.new()
	view.setup(entry)
	_views[entry.id] = view
	add_child(view)


func _on_removed(id: int, picker_id: int) -> void:
	var view := _views.get(id) as PickupView
	if view == null:
		return
	_views.erase(id)
	view.collect(GameState.player_node(picker_id))


func _on_cleared() -> void:
	for id: int in _views:
		(_views[id] as PickupView).queue_free()
	_views.clear()
