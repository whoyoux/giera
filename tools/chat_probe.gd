extends Node
## Test sieci czatu: wypisuje odebrane wiadomosci, a z --chat-send wysyla wiadomosci i spam.
## Uruchamia go tools/chat_net_test.sh.

const SPAM := 20


func _ready() -> void:
	Chat.message_received.connect(func(sender_id: int, text: String, _team_only: bool) -> void:
		print("[chat] %s %d %s" % [GameState.display_name(sender_id), text.length(), text.left(16)]))
	if not Net.args.has("chat-send"):
		return
	await get_tree().create_timer(3.0).timeout
	Chat.send("  czesc [b]x[/b]\n\t")
	Chat.send("y".repeat(500))
	# Czeka, az minie okno limitu, a potem omija limit klienta, jak zmieniony klient.
	await get_tree().create_timer(Chat.BURST_SECONDS + 3.0).timeout
	for index in SPAM:
		Chat._submit.rpc_id(1, "spam")
	Chat._submit.rpc_id(1, " \n\t ")
