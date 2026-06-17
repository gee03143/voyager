class_name TimerHandle
extends RefCounted

var _mgr: TimerManager
var _id: int

func _init(mgr: TimerManager, id: int) -> void:
	_mgr = mgr
	_id = id

func remaining() -> float:
	return _mgr.get_remaining(_id)

func is_valid() -> bool:
	return _mgr.is_active(_id)

func pause() -> void:
	_mgr.pause(_id)

func is_paused() -> bool:
	return _mgr.is_paused(_id)

func resume() -> void:
	_mgr.resume(_id)

func cancel() -> void:
	_mgr.clear(_id)
