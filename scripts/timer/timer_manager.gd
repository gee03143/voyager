class_name TimerManager
extends Node

# id -> { end_ms, remaining_ms, paused, on_finished }
var _timers: Dictionary = {}
var _next_id: int = 1

func set_timer(duration: float, on_finished: Callable) -> TimerHandle:
	var id := _next_id
	_next_id += 1
	var ms := int(max(duration, 0.0) * 1000.0)
	_timers[id] = {
		"end_ms": Time.get_ticks_msec() + ms,
		"remaining_ms": ms,
		"paused": false,
		"on_finished": on_finished,
	}
	return TimerHandle.new(self, id)

func get_remaining(id: int) -> float:
	if not _timers.has(id):
		return 0.0
	var t: Dictionary = _timers[id]
	if t["paused"]:
		return t["remaining_ms"] / 1000.0
	return max(t["end_ms"] - Time.get_ticks_msec(), 0) / 1000.0

func is_active(id: int) -> bool:
	return _timers.has(id)

func is_paused(id: int) -> bool:
	if not _timers.has(id):
		return false
	return _timers[id]["paused"]

func pause(id: int) -> void:
	if not _timers.has(id):
		return
	var t: Dictionary = _timers[id]
	if t["paused"]:
		return
	t["remaining_ms"] = max(t["end_ms"] - Time.get_ticks_msec(), 0)
	t["paused"] = true

func resume(id: int) -> void:
	if not _timers.has(id):
		return
	var t: Dictionary = _timers[id]
	if not t["paused"]:
		return
	t["end_ms"] = Time.get_ticks_msec() + t["remaining_ms"]
	t["paused"] = false

func clear(id: int) -> void:
	_timers.erase(id)

func _process(_delta: float) -> void:
	if _timers.is_empty():
		return
	var now := Time.get_ticks_msec()
	var fired: Array = []
	for id in _timers:
		var t: Dictionary = _timers[id]
		if not t["paused"] and now >= t["end_ms"]:
			fired.append(id)
	for id in fired:
		var cb: Callable = _timers[id]["on_finished"]
		_timers.erase(id)                 # 콜백 전에 제거(재진입·취소 안전)
		if cb.is_valid():
			cb.call()
