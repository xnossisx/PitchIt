extends Timer

var peer = ENetMultiplayerPeer.new()
const PlayerData = preload("res://Scenes/Multiplayer Menu/PlayerData.gd")
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# connect("lobby_ready", continue_init)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func continue_init():
	set_username(username)

func init_server(port, usern):
	username = usern
	if port != null:
		peer.create_server(port.to_int())
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(add_player)
		GameManager.change_game_state(GameManager.game_state_enum.lobby, false)
		await GameManager.scene_changed
		#while !get_parent().has_node("/root/LobbyScene"):
		#	await get_tree().create_timer(0.1).timeout
		#	pass
		#await get_tree().create_timer(5.0).timeout
		continue_init()

var cards = {}
var votes = {}
var score_card = {}
var players = {}
var username = ""

func add_player(id):
	pass

func join_server(port, usern):
	username = usern
	print(port.to_int())
	if multiplayer.multiplayer_peer == null && port.to_int() != null:
		var ip_addresses = ["localhost"]
		for i in ip_addresses:
			print(i)
			if !i.begins_with("f"):
				peer.create_client(i, port.to_int())
				multiplayer.multiplayer_peer = peer
				if !multiplayer.connected_to_server.is_connected(_on_connected_ok):
					multiplayer.connected_to_server.connect(_on_connected_ok)

func _on_connected_ok():
	GameManager.change_game_state(GameManager.game_state_enum.lobby, false)
	await GameManager.scene_changed
	set_username.rpc_id(1, username)

@rpc("any_peer", "reliable")
func set_username(username: String):
	var lobby_scene = get_node("/root/LobbyScene")
	if multiplayer.get_remote_sender_id() == 0:
		MultiplayerManager.players[multiplayer.get_unique_id()] = PlayerData.new()
		MultiplayerManager.players[multiplayer.get_unique_id()].username = username
		lobby_scene.show_player(multiplayer.get_unique_id())
	elif GameManager.game_state != GameManager.game_state_enum.lobby:
		join_setup.rpc_id(multiplayer.get_remote_sender_id(), false)
	else:
		join_setup.rpc_id(multiplayer.get_remote_sender_id(), true)
		MultiplayerManager.players[multiplayer.get_remote_sender_id()] = PlayerData.new()
		MultiplayerManager.players[multiplayer.get_remote_sender_id()].username = username
		lobby_scene.show_player(multiplayer.get_remote_sender_id())
	if multiplayer.is_server():
		update_player_data.rpc(serialize(players))

@rpc("any_peer", "reliable")
func update_player_data(data):
	if !multiplayer.is_server():
		for player_id in data:
			players[player_id] = deserialize(data[player_id])
		cards = get_cards()
	var lobby_scene = get_parent().get_node("LobbyScene")
	
	if lobby_scene != null:
		lobby_scene.reset_player_data()
	else:
		print("lobby scene is null")

@rpc("any_peer", "reliable")
func join_setup(success: bool):
	if success:
		GameManager.change_game_state(GameManager.game_state_enum.lobby, false)
		await GameManager.scene_changed
		var lobby_scene = get_parent().get_node("LobbyScene")
		set_username(username)
		lobby_scene.reset_player_data()
	else:
		multiplayer.multiplayer_peer = null

func run_game_loop():
	if multiplayer.is_server():
		#for i in range(2):
		#	run_game()
		run_game()

@rpc("any_peer", "reliable")
func run_game():
	# Run creation screen
	GameManager.change_game_state.rpc(GameManager.game_state_enum.creation, false)
	start(GameManager.creation_time)
	await self.timeout

	# Get cards
	get_parent().get_node("/root/Creation_Scene").export_card.rpc()
	while get_cards().size() < players.size():
		await get_tree().create_timer(0.5).timeout
	print(get_cards())
	 #update_player_data.rpc(serialize(players))
	# Change to display
	GameManager.change_game_state.rpc(GameManager.game_state_enum.display, false)
	await get_tree().create_timer(2).timeout
	cards = get_cards()
	for product in get_cards().values():
		get_parent().get_node("/root/DisplayScene").display_card.rpc(product.serialize())
		start(GameManager.presentation_time)
		await self.timeout

	# Voting
	update_player_data.rpc(serialize(players))
	GameManager.change_game_state.rpc(GameManager.game_state_enum.voting, false)
	await get_tree().create_timer(20).timeout

	get_parent().get_node("/root/VotingScene").send_vote.rpc()
	while votes.size() < players.size():
		await get_tree().create_timer(0.5).timeout

	var round_results = {}
	for player in players.keys():
		round_results[player] = 0
	
	var has_winner = false
	for vote in votes.values():
		if vote == -1:
			continue
		round_results[vote] += 1
		MultiplayerManager.players[vote].score += 100000
		if MultiplayerManager.players[vote].score >= GameManager.win_threshold: 
			has_winner = true
		
	# Results
	GameManager.change_game_state.rpc(GameManager.game_state_enum.results, false)
	await get_tree().create_timer(3).timeout
	update_player_data.rpc(serialize(players))
	get_parent().get_node("/root/ResultsScene").show_scores.rpc(round_results)
	await get_tree().create_timer(15).timeout

	if has_winner:
		reset.rpc()
	else:
		run_game()

	# Optional: Offer replay

@rpc("any_peer", "call_local", "reliable")
func handle_display_pain(card: Dictionary):
	await GameManager.scene_changed
	get_parent().get_node("/root/DisplayScene").display_card(card)

@rpc("any_peer","call_local","reliable")
func reset():
	GameManager.change_game_state(GameManager.game_state_enum.multiplayer_main_menu, false)
	multiplayer.multiplayer_peer.close()
	await GameManager.scene_changed
	var home_scene = get_parent().get_node("/root/Multiplayer_Menu")
	home_scene.USERNAME_READ.text = username
	var cards = {}
	var votes = {}
	var score_card = {}
	var players = {}

func deserialize(data: Dictionary):
	var player = PlayerData.new()
	player.username = data["username"]
	player.score = data["score"]
	player.data = PitchCardData.deserialize(data["data"]) if data["data"] != null else null
	return player

func serialize(list: Dictionary):
	var ret = {}
	for player_id in list.keys():
		ret[player_id] = list[player_id].serialize()
	return ret

func get_cards():
	var ret = {}
	for key in players.keys():
		ret[key] = players[key].data
	return ret

@rpc("any_peer", "call_local", "reliable")
func import_card(pd: Dictionary):
	print(pd.keys())
	print(pd["user"])
	MultiplayerManager.players[multiplayer.get_remote_sender_id()].data = PitchCardData.deserialize(pd)
	print("data saved: " + str(MultiplayerManager.players[multiplayer.get_remote_sender_id()]))
