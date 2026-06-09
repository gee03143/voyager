extends VBoxContainer

const ALARM_ROW := preload("res://scenes/timer/AlarmRow.tscn")
const SAVE_DEBOUNCE := 0.5

@onready var list: VBoxContainer = $List
@onready var add_button: Button = $AddButton

var _rows: Array[AlarmRow] = []
var _save_timer: Timer
var _alarm_clock: AlarmClock # 추후 알람 탭이 아닌 Autoload로 올려 앱 전역에서 알람 트리거 고려

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	add_child(_save_timer)
	_save_timer.timeout.connect(func(): Save.save_game())

	add_button.pressed.connect(_on_add_pressed)

	for alarm in Save.alarms:        # 저장된 알람 복원
		_add_row(alarm)
		
	_alarm_clock = AlarmClock.new()
	add_child(_alarm_clock)
	_alarm_clock.alarms = Save.alarms
	_alarm_clock.alarm_triggered.connect(_on_alarm_triggered)

func _add_row(alarm: Alarm) -> void:
	var row := ALARM_ROW.instantiate() as AlarmRow
	list.add_child(row)              # 트리에 먼저 → @onready 준비
	row.setup(alarm)                 # (changed 연결 '전'이라 setup 이 저장 안 유발)
	row.changed.connect(_on_list_changed)
	row.delete_requested.connect(_on_row_delete)
	_rows.append(row)

func _on_add_pressed() -> void:
	_add_row(_new_alarm_now())            # 현재 시각으로 새 알
	_on_list_changed()                    # 새 알람 저장
	
func _new_alarm_now() -> Alarm:
	var now := Time.get_time_dict_from_system()   # {hour, minute, second} (24시간)
	var a := Alarm.new()
	a.hour = now.hour
	a.minute = now.minute
	return a    

func _on_row_delete(row: AlarmRow) -> void:
	_rows.erase(row)
	row.queue_free()
	_on_list_changed()

func _on_list_changed() -> void:
	# 행 전체 → Save.alarms 스냅샷 (메모리 즉시)
	Save.alarms.clear()
	for r in _rows:
		Save.alarms.append(r.get_data())
	_save_timer.start()              # 디스크 저장은 디바운스
	
func _on_alarm_triggered(alarm: Alarm) -> void:
	Sound.play_set(Save.settings.sound_set)
	print("[알람] %02d:%02d  %s" % [alarm.hour, alarm.minute, alarm.label])
