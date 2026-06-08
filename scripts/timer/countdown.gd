class_name CountDown
extends Node

signal ticked(time_left: float)
signal finished

var duration: float = 0.0
var time_left: float = 0.0
var running: bool = false

func configure(seconds: float) -> void:
	duration = seconds
	time_left = seconds
	ticked.emit(time_left)

func start() -> void:
	if time_left <= 0.0:
		time_left = duration
	running = true
	
func pause() -> void:
	running = false
	
func reset() -> void:
	running = false
	time_left = duration
	ticked.emit(time_left)
	
func is_running() -> bool:
	return running


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not running:
		return
	time_left = max(time_left - delta, 0.0)
	ticked.emit(time_left)
	if time_left <= 0.0:
		running = false
		finished.emit()
