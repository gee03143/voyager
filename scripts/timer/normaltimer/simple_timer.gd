class_name SimpleTimer
extends Node

signal timer_finished

var duration: float = 0.0
var started: bool = false
var finished: bool = false
var _handle: TimerHandle = null

func configure(seconds: float) -> void:
	duration = seconds
	started = false
	finished = false
	_clear_handle()

func start() -> void:
	if finished or duration <= 0.0:    # 0초 시작 방지도 모델로
		return
	started = true
	if _handle == null or not _handle.is_valid():
		_handle = Timers.set_timer(duration, _on_finished)   # 첫 시작
	elif _handle.is_paused():
		_handle.resume()       

func pause() -> void:
	if _handle != null and _handle.is_valid() and not _handle.is_paused():
		_handle.pause()

func reset() -> void:
	started = false
	finished = false
	_clear_handle()

func is_running() -> bool:
	return _handle != null and _handle.is_valid() and not _handle.is_paused()

func time_left() -> float:
	if _handle != null and _handle.is_valid():
		return _handle.remaining()
	if finished:
		return 0.0
	return duration                     # standby = 전체 길이

func _clear_handle() -> void:
	if _handle != null:
		if _handle.is_valid():
			_handle.cancel()
		_handle = null

func _on_finished() -> void:
	_handle = null
	finished = true
	timer_finished.emit()
