extends Node

const SETS := [
	preload("res://assets/sounds/Piano_Ui_Set1.wav"),
	preload("res://assets/sounds/Piano_Ui_Set2.wav"),
]

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)

func play_set(index: int) -> void:
	if index < 0 or index >= SETS.size():
		return
	_player.stream = SETS[index]
	_player.play()
