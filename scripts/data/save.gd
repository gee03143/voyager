extends Node

const SAVE_PATH := "user://save.json"
const VERSION := 7
const RECORDS_PATH := "user://records.json"
const RECORDS_VERSION := 1
const JOURNAL_PATH := "user://journal.json"
const JOURNAL_VERSION := 1

var voyage := Voyage.new()
var letters := LetterArchive.new()
var lexicon := Lexicon.new()
var activity_log := ActivityLog.new()
var journal := Journal.new()
var settings := AppSettings.new()
var alarms: Array[Alarm] = []
var todo_groups: Array[TodoGroup] = []
var current_group_index: int = 0

var habit_defs: Array = []      # [{id, title, active_days}]  공유 정의(단일 출처, 순서=표시순서)
var habit_weeks: Array = []     # [{week_start, checks: {id:[7]}}]  주별 체크(희소)

var _play_base_seconds: float = 0.0     # 세션 시작 시점의 누적 플레이
var _session_start_ms: int = 0

var _play_ckpt_ms: int = 0         # 적립 체크포인트(모노토닉)

func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		load_game()
	if FileAccess.file_exists(RECORDS_PATH):
		load_records()
	if FileAccess.file_exists(JOURNAL_PATH):
		load_journal()
	if todo_groups.is_empty():
		todo_groups.append(TodoGroup.new())
	current_group_index = clampi(current_group_index, 0, todo_groups.size() - 1)
	_play_base_seconds = voyage.total_play_seconds
	_session_start_ms = Time.get_ticks_msec()
	_play_ckpt_ms = _session_start_ms
	var play_timer := Timer.new()
	play_timer.wait_time = 60.0
	play_timer.one_shot = false
	add_child(play_timer)
	play_timer.timeout.connect(_accumulate_play_day)   # 메모리 누적만(자정 근사)
	play_timer.start()
	get_tree().auto_accept_quit = false
	save_game()
	save_records()
	save_journal()
	settings.changed.connect(save_game)
	voyage.changed.connect(save_game)
	activity_log.changed.connect(save_records)
	journal.changed.connect(save_journal)
	lexicon.changed.connect(save_game)
	letters.changed.connect(save_game)
		
func _accumulate_play_day() -> void:
	var now_ms := Time.get_ticks_msec()
	var elapsed := (now_ms - _play_ckpt_ms) / 1000.0
	_play_ckpt_ms = now_ms
	activity_log.add_play(_local_day_iso(), elapsed)

func _local_day_iso() -> String:
	var t := Time.get_date_dict_from_system()     # 로컬 날짜(habit과 동일 기준)
	return "%04d-%02d-%02d" % [t.year, t.month, t.day]

func save_game() -> void:
	voyage.total_play_seconds = _play_base_seconds + (Time.get_ticks_msec() - _session_start_ms) / 1000.0
	# alarms
	var alarm_dicts := []
	for a in alarms:
		alarm_dicts.append(a.to_dict())
	
	# todos
	var todo_group_dicts := []
	for t in todo_groups:
		todo_group_dicts.append(t.to_dict())
	
	var data := {
		"version": VERSION,
		"settings": settings.to_dict(),
		"alarms": alarm_dicts,
		"todo_groups": todo_group_dicts,
		"habit_defs": habit_defs,
		"habit_weeks": habit_weeks,
		"voyage": voyage.to_dict(),
		"letters": letters.to_dict(),
		"lexicon": lexicon.to_dict(),
	}
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Fail to Save: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
		
func load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Fail to Load: %s" % FileAccess.get_open_error())
		return
	var text := file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Fail to parse save file - Use DEfault Value")
		return
	# var v = parsed.get("version", 1)으로 마이그레이션 분기 가능, 1은 version 넘버
	var s = parsed.get("settings", {})
	if typeof(s) == TYPE_DICTIONARY:
		settings.from_dict(s)
		
	alarms.clear()
	for d in parsed.get("alarms", []):
		if typeof(d) == TYPE_DICTIONARY:
			alarms.append(Alarm.from_dict(d))
			
	todo_groups.clear()
	if parsed.has("todo_groups"):
		for d in parsed.get("todo_groups", []):
			if typeof(d) == TYPE_DICTIONARY:
				todo_groups.append(TodoGroup.from_dict(d))
	elif parsed.has("todos"):
		var g := TodoGroup.new()
		g.name = "기본"
		g.sort_key = int(parsed.get("todos_sort_key", 0))
		g.sort_desc = bool(parsed.get("todos_sort_desc", false))
		for d in parsed.get("todos", []):
			if typeof(d) == TYPE_DICTIONARY:
				g.tasks.append(Todo.from_dict(d))
		todo_groups.append(g)
		
	var raw_defs = parsed.get("habit_defs", [])
	habit_defs = raw_defs if typeof(raw_defs) == TYPE_ARRAY else []
	var raw_weeks = parsed.get("habit_weeks", [])
	habit_weeks = raw_weeks if typeof(raw_weeks) == TYPE_ARRAY else []
	
	var rv = parsed.get("voyage", {})
	if typeof(rv) == TYPE_DICTIONARY:
		voyage.from_dict(rv)
		
	var rl = parsed.get("letters", {})
	if typeof(rl) == TYPE_DICTIONARY:
		letters.from_dict(rl)
	
	var rlex = parsed.get("lexicon", {})
	if typeof(rlex) == TYPE_DICTIONARY:
		lexicon.from_dict(rlex)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
		
func save_records() -> void:
	_accumulate_play_day()
	var data := {
		"version": RECORDS_VERSION,
		"activity_log": activity_log.to_dict(),
	}
	var file := FileAccess.open(RECORDS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Fail to Save records: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_records() -> void:
	var file := FileAccess.open(RECORDS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var ra = parsed.get("activity_log", {})
	if typeof(ra) == TYPE_DICTIONARY:
		activity_log.from_dict(ra)

func save_journal() -> void:
	var data := journal.to_dict()        # {groups, docs}
	data["version"] = JOURNAL_VERSION
	var file := FileAccess.open(JOURNAL_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Fail to Save journal: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_journal() -> void:
	var file := FileAccess.open(JOURNAL_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		journal.from_dict(parsed)
		
func quit_game() -> void:
	save_game()
	save_records()
	save_journal()
	get_tree().quit()
