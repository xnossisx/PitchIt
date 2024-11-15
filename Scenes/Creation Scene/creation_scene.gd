extends Node2D

const WIDTH = 800
const HEIGHT = 600

const PitchCardData = preload("res://Card/Pitch/pitch_card_data.gd")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().create_timer(GameManager.get_round_time())
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

	

@rpc("any_peer", "call_local", "reliable") # Authority should be able to request this
func export_card():
	var data = PitchCardData.new()
	data.title = $MarginContainer/VSplitContainer/MarginContainer/VBoxContainer/Title.text
	data.slogan = $MarginContainer/VSplitContainer/MarginContainer/VBoxContainer/MarginContainer/Slogan.text
	data.logo = $MarginContainer/VSplitContainer/HSplitContainer/DrawingScene.image_texture.get_image()
	data.user = "test"
	import_card.rpc(data)

@rpc("authority", "reliable")
func import_card(pd: PitchCardData):
	MultiplayerManager.cards.append(pd)


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_released("Esc"):
		GameManager.quit_game(true)
