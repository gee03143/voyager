class_name SimpleTimer
extends Node

signal ticked(time_left: float)
signal timer_finished

var duration: float = 0.0
var started: bool = false
var finished: bool = false
var _countdown: CountDown

func _ready() -> void:
	_countdown = CountDown.new()
	add_child(_countdown)
	_countdown.ticked.connect(_on_countdown_ticked)
	_countdown.finished.connect(_on_countdown_finished)

func configure(seconds: float) -> void:
	duration = seconds
	started = false
	finished = false
	_countdown.configure(seconds)

func start() -> void:
	if not finished and duration > 0.0:    # 0초 시작 방지도 모델로
		started = true
		_countdown.start()

func pause() -> void:
	_countdown.pause()

func reset() -> void:
	started = false
	finished = false
	_countdown.reset()

func is_running() -> bool:
	return _countdown.is_running()

func _on_countdown_ticked(time_left: float) -> void:
	ticked.emit(time_left)

func _on_countdown_finished() -> void:
	finished = true
	timer_finished.emit()
