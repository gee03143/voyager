extends Node

const SAVE_PATH := "user://save.json"
const VERSION := 8
const RECORDS_PATH := "user://records.json"
const RECORDS_VERSION := 2
const JOURNAL_PATH := "user://journal.json"
const JOURNAL_VERSION := 1
const TODO_PATH := "user://todo.json"
const TODO_VERSION := 1
const GRATITUDE_PATH := "user://gratitude.json"
const GRATITUDE_VERSION := 1
const MOOD_PATH := "user://mood.json"
const MOOD_VERSION := 1

var voyage := Voyage.new()
var letters := LetterArchive.new()
var lexicon := Lexicon.new()
var activity_log := ActivityLog.new()
var journal := Journal.new()
var gratitude := Gratitude.new()
var mood := Mood.new()
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
	if FileAccess.file_exists(TODO_PATH):
		load_todo()
	if FileAccess.file_exists(GRATITUDE_PATH):
		load_gratitude()
	if FileAccess.file_exists(MOOD_PATH):
		load_mood()
	if todo_groups.is_empty():
		var g := TodoGroup.new()
		g.is_default = true
		todo_groups.append(g)
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
	save_todo()
	save_gratitude()
	save_mood()
	settings.changed.connect(save_game)
	voyage.changed.connect(save_game)
	activity_log.changed.connect(save_records)
	journal.changed.connect(save_journal)
	lexicon.changed.connect(save_game)
	letters.changed.connect(save_game)
	gratitude.changed.connect(save_gratitude)
	mood.changed.connect(save_mood)
		
func _accumulate_play_day() -> void:
	var now_ms := Time.get_ticks_msec()
	var elapsed := (now_ms - _play_ckpt_ms) / 1000.0
	_play_ckpt_ms = now_ms
	activity_log.add_play(_local_day_iso(), elapsed)

func _local_day_iso() -> String:
	var t := Time.get_date_dict_from_system()     # 로컬 날짜(habit과 동일 기준)
	return "%04d-%02d-%02d" % [t.year, t.month, t.day]

func current_play_seconds() -> float:
	return _play_base_seconds + (Time.get_ticks_msec() - _session_start_ms) / 1000.0

func save_game() -> void:
	voyage.total_play_seconds = _play_base_seconds + (Time.get_ticks_msec() - _session_start_ms) / 1000.0
	var alarm_dicts := []
	for a in alarms:
		alarm_dicts.append(a.to_dict())
	
	var data := {
		"version": VERSION,
		"settings": settings.to_dict(),
		"alarms": alarm_dicts,
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
	var s = parsed.get("settings", {})
	if typeof(s) == TYPE_DICTIONARY:
		settings.from_dict(s)
		
	alarms.clear()
	for d in parsed.get("alarms", []):
		if typeof(d) == TYPE_DICTIONARY:
			alarms.append(Alarm.from_dict(d))
			
	if parsed.has("todo_groups"):                     # todo.json 분리 전 구버전 데이터 → 마이그레이션
		for d in parsed.get("todo_groups", []):
			if typeof(d) == TYPE_DICTIONARY:
				todo_groups.append(TodoGroup.from_dict(d))
		if not todo_groups.is_empty() and not todo_groups[0].is_default:
			todo_groups[0].is_default = true           # 구버전엔 is_default 없었음 → 첫 그룹을 기본으로 지정
	elif parsed.has("todos"):
		var g := TodoGroup.new()
		g.is_default = true
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

func save_todo() -> void:
	var todo_group_dicts := []
	for t in todo_groups:
		todo_group_dicts.append(t.to_dict())
	var data := {
		"version": TODO_VERSION,
		"todo_groups": todo_group_dicts,
	}
	var file := FileAccess.open(TODO_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Fail to Save todo: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_todo() -> void:
	var file := FileAccess.open(TODO_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	todo_groups.clear()
	for d in parsed.get("todo_groups", []):
		if typeof(d) == TYPE_DICTIONARY:
			todo_groups.append(TodoGroup.from_dict(d))
		
func quit_game() -> void:
	save_game()
	save_records()
	save_journal()
	save_todo()
	save_gratitude()
	save_mood()
	get_tree().quit()
	
# 원본이 삭제된 참조형 이벤트(journal/mood/gratitude) 판정.
# 화면에서 빼는 용도로만 씀 — 파일(records.json)의 이벤트는 그대로 둔다
func is_orphan_event(e: Dictionary) -> bool:
	match str(e.get("type", "")):
		"journal":
			return not journal.has_doc(int(e.get("doc_id", 0)))
		"mood":
			return mood.entry_by_id(int(e.get("entry_id", 0))).is_empty()   # 조회 함수가 이미 있음
		"gratitude":
			return not gratitude.has_entry(int(e.get("entry_id", 0)))
	return false                                                            # 나머지 타입은 참조가 없어 orphan이 될 수 없음
	
func activity_entries_for(date_iso: String) -> Array:    # 로그 이벤트 + 습관 파생 완료를 날짜 기준으로 병합(raw, 포맷 없음)
	var out := []
	for e in activity_log.events:
		if is_orphan_event(e):        # 원본 삭제된 참조형 이벤트는 제외
			continue
		var end_day := DateUtil.local_day_iso(int(e.get("ts", 0)))
		var start_day := end_day
		if e.has("start_ts"):
			start_day = DateUtil.local_day_iso(int(e["start_ts"]))
		if start_day <= date_iso and date_iso <= end_day:    # ISO 문자열 비교 = 날짜순
			out.append(e)
	var titles := {}
	for d in habit_defs:
		titles[int(d["id"])] = str(d.get("title", ""))
	for wk in habit_weeks:
		var ws := str(wk.get("week_start", ""))
		var checks: Dictionary = wk.get("checks", {})
		for k in checks:
			var hid := int(k)
			if not titles.has(hid):
				continue
			var arr = checks[k]
			for di in 7:
				if di < arr.size() and bool(arr[di]) and DateUtil.add_days(ws, di) == date_iso:
					out.append({"ts": 1 << 62, "type": "habit", "title": titles[hid]})
	out.sort_custom(func(a, b): return a["ts"] < b["ts"])
	return out

func save_gratitude() -> void:
	var data := gratitude.to_dict()
	data["version"] = GRATITUDE_VERSION
	var file := FileAccess.open(GRATITUDE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Fail to Save gratitude: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_gratitude() -> void:
	var file := FileAccess.open(GRATITUDE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		gratitude.from_dict(parsed)

func save_mood() -> void:
	var data := mood.to_dict()
	data["version"] = MOOD_VERSION
	var file := FileAccess.open(MOOD_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Fail to Save mood: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_mood() -> void:
	var file := FileAccess.open(MOOD_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		mood.from_dict(parsed)
