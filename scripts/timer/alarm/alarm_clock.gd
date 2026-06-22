extends Node

# 전역 알람 시계(autoload `Alarms`): 벽시계 시각을 폴링해 Save.alarms를 발화.
# 뷰와 무관하게 상주 → 알람 패널을 닫아도 울림. 단일 진실 = Save.alarms.

const MAX_CATCHUP_MINUTES := 2   # 이보다 큰 갭 = 묵은 알람 → 발화 없이 동기화만

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
	var elapsed := (m - _last_minute + 1440) % 1440   # 지난 분 수(자정 넘김 안전)
	if elapsed == 0:
		return
	if elapsed <= MAX_CATCHUP_MINUTES:
		for k in range(1, elapsed + 1):               # 놓친 분들도 늦게라도(fire-late)
			_fire_minute((_last_minute + k) % 1440)
	_last_minute = m

func _fire_minute(minute: int) -> void:
	for a in Save.alarms:
		if a.enabled and a.hour * 60 + a.minute == minute:
			Sound.play_set(Save.settings.sound_set)
			alarm_triggered.emit(a)
