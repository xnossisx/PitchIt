extends Node2D

@onready var SERVER_PORT_READ: TextEdit = $MarginContainer/VSplitContainer/MarginContainer/TextEdit

var peer = ENetMultiplayerPeer.new()
@export var player_scene : PackedScene

func add_player(id = 1):
	var player = player_scene.instantiate()
	player.name = str(id)
	call_deferred("add_child", player)


func _on_host_pressed() -> void:
	if SERVER_PORT_READ.text != null:
		peer.create_server(SERVER_PORT_READ.text.to_int())
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(add_player)
		add_player()


func _on_join_pressed() -> void:
	if SERVER_PORT_READ.text.to_int() != null:
		var ip_addresses = IP.get_local_addresses()
		for i in ip_addresses:
			if !i.begins_with("f"):
				print(i)
				peer.create_client(i, SERVER_PORT_READ.text.to_int())
				multiplayer.multiplayer_peer = peer
