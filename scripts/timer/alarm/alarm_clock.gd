class_name AlarmClock
extends Node

signal alarm_triggered(alarm: Alarm)

var alarms: Array[Alarm] = []
var _last_minute: int = -1

func _ready() -> void:
	_last_minute = _current_minute()    # 시작한 분은 발화 안 함

	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	add_child(t)
	t.timeout.connect(_check)

func _current_minute() -> int:
	var now := Time.get_time_dict_from_system()
	return now.hour * 60 + now.minute

func _check() -> void:
	var m := _current_minute()
	if m == _last_minute:
		return                          # 같은 분 → 아무것도 안 함
	_last_minute = m                    # 새 분 진입
	for a in alarms:
		if a.enabled and a.hour * 60 + a.minute == m:
			alarm_triggered.emit(a)
