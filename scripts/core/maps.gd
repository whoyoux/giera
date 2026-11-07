extends Node
## Spis map i mapa biezacej sesji. Serwer wybiera ja z trybu albo z --map=, a klient dostaje ja
## w stanie meczu, zanim powstana postacie. Sam swiat podmienia main.gd po sygnale changed.

signal changed(id: String)

## Mapa tla w menu, zanim gracz dolaczy do gry.
const DEFAULT := "forest"

var current_id := DEFAULT

var _catalog := {}


func _init() -> void:
	for info: MapInfo in [ForestMapInfo.new(), CityMapInfo.new(), ValleyMapInfo.new()]:
		_catalog[info.id] = info


func has(id: String) -> bool:
	return _catalog.has(id)


func ids() -> Array:
	return _catalog.keys()


func info(id := "") -> MapInfo:
	return _catalog[current_id if id.is_empty() else id]


## Zmienia mape. Swiat podmienia sie od razu, wiec po powrocie z tej funkcji nowa mapa juz stoi.
func select(id: String) -> void:
	if not has(id):
		push_error("Nieznana mapa: %s" % id)
		return
	if id == current_id:
		return
	current_id = id
	print("[mapa] %s" % id)
	changed.emit(id)
