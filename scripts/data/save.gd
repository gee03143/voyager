extends Node

const SAVE_PATH := "user://save.json"
const VERSION := 2

var settings := AppSettings.new()
var alarms: Array[Alarm] = []
var todo_groups: Array[TodoGroup] = []
var current_group_index: int = 0

func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		load_game()
	if todo_groups.is_empty():
		todo_groups.append(TodoGroup.new())          # 신규/빈 경우 기본 그룹
	current_group_index = clampi(current_group_index, 0, todo_groups.size() - 1)
	save_game()                                       # 마이그레이션·기본그룹 디스크 반영
	settings.changed.connect(save_game)
	
		
func save_game() -> void:
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
