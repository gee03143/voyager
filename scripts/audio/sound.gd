extends Node

const SETS := [
	preload("res://assets/sounds/Piano_Ui_Set1.wav"),
	preload("res://assets/sounds/Piano_Ui_Set2.wav"),
]

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	set_master_volume(Save.settings.master_volume)

func play_set(index: int) -> void:
	if index < 0 or index >= SETS.size():
		return
	_player.stream = SETS[index]
	_player.play()

func set_master_volume(linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(0, linear <= 0.0)          # 0 = 음소거(-inf dB 회피)
	if linear > 0.0:
		AudioServer.set_bus_volume_db(0, linear_to_db(linear))
