extends Node

var peer = ENetMultiplayerPeer.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func init_server(port, usern):
	username = usern
	if port != null:
		peer.create_server(port.to_int())
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(add_player)
		add_player(1)
		GameManager.change_game_state(GameManager.game_state_enum.lobby, false)

var cards = []
var players = {}
var username = ""

func add_player(id):
	players[id]

func join_server(port, usern):
	username = usern
	print(port.to_int())
	if port.to_int() != null:
		var ip_addresses = ["localhost"]
		for i in ip_addresses:
			print(i)
			if !i.begins_with("f"):
				peer.create_client(i, port.to_int())
				multiplayer.multiplayer_peer = peer
				if !multiplayer.connected_to_server.is_connected(_on_connected_ok):
					multiplayer.connected_to_server.connect(_on_connected_ok)

func _on_connected_ok():
	set_username.rpc(username)

@rpc("authority","reliable")
func set_username(username: String):
	if GameManager.game_state != GameManager.game_state_enum.lobby:
		join_setup.rpc(multiplayer.get_remote_sender_id(), false)
	else:
		join_setup.rpc(multiplayer.get_remote_sender_id(), true)
		MultiplayerManager.players[multiplayer.get_remote_sender_id()] = username

@rpc("any_peer", "reliable")
func join_setup(success: bool):
	if success:
		GameManager.change_game_state(GameManager.game_state_enum.lobby, false)
	else:
		multiplayer.multiplayer_peer = null

func run_game():
	# Run creation screen
	GameManager.change_game_state.rpc(GameManager.game_state_enum.creation, false)
	await get_tree().create_timer(GameManager.creation_time).timeout
	
	# Get cards
	print(get_tree().get_child("Creation_Scene"))
	get_tree().get_child("Creation_Scene").export_card.rpc()
	# Change to display
	GameManager.change_game_state.rpc(GameManager.game_state_enum.display, false)
	for product in cards:
		get_tree().current_scene.display.rpc(product)
		await get_tree().create_time(GameManager.presentation_time).timeout
	
	# Voting
	GameManager.change_game_state.rpc(GameManager.game_state_enum.voting, false)
	
	await get_tree().create_time(20).timeout
	
	# Results
	GameManager.change_game_state.rpc(GameManager.game_state_enum.results, false)
