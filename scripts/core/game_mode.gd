class_name GameMode
extends RefCounted
## Tryby gry. Jeden proces serwera prowadzi jeden tryb, a menu wybiera serwer po jego porcie.
## Kolejny serwer dopisuje sie w compose.yaml.

enum Id { DEATHMATCH, BATTLE_ROYALE }

const INFO := {
	Id.DEATHMATCH: {
		"key": "deathmatch",
		"title": "Deathmatch",
		"hint": "Odradzasz się i zbierasz zabójstwa.",
		"port": 7777,
	},
	Id.BATTLE_ROYALE: {
		"key": "battle_royale",
		"title": "Battle Royale",
		"hint": "Jedno życie. Wygrywa ostatni żywy.",
		"port": 7778,
	},
}


static func key_of(id: int) -> String:
	return INFO[id].key


static func title_of(id: int) -> String:
	return INFO[id].title


static func hint_of(id: int) -> String:
	return INFO[id].hint


static func port_of(id: int) -> int:
	return INFO[id].port


## Port wpisany w adresie liczy sie tylko wtedy, gdy nie jest portem zadnego trybu. Inaczej
## zapisany adres z portem 7777 prowadzilby do Deathmatchu mimo wyboru innego trybu.
static func port_for_address(address_port: int, id: int) -> int:
	for other: int in INFO:
		if INFO[other].port == address_port:
			return port_of(id)
	return address_port if address_port > 0 else port_of(id)


## Numer trybu po nazwie z linii polecen albo ustawien. -1, gdy nie ma takiego.
static func from_key(key: String) -> int:
	for id: int in INFO:
		if INFO[id].key == key:
			return id
	return -1
