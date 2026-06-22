extends Node

# 전역 알람 시계(autoload `Alarms`): 벽시계 시각을 폴링해 Save.alarms를 발화.
# 뷰와 무관하게 상주 → 알람 패널을 닫아도 울림. 단일 진실 = Save.alarms.

signal alarm_triggered(alarm: Alarm)

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
		return
	_last_minute = m
	for a in Save.alarms:                # 주입 대신 Save를 직접(편집 즉시 반영)
		if a.enabled and a.hour * 60 + a.minute == m:
			_fire(a)

func _fire(a: Alarm) -> void:
	Sound.play_set(Save.settings.sound_set)
	alarm_triggered.emit(a)
