extends Node

const SAVE_PATH := "user://save.json"
const VERSION := 1

var settings := AppSettings.new()
var alarms: Array[Alarm] = []
var todos: Array[Todo] = []

func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		load_game()
	else:
		save_game()
	settings.changed.connect(save_game)
	
		
func save_game() -> void:
	# alarms
	var alarm_dicts := []
	for a in alarms:
		alarm_dicts.append(a.to_dict())
	
	# todos
	var todo_dicts := []
	for t in todos:
		todo_dicts.append(t.to_dict())
	
	var data := {
		"version": VERSION,
		"settings": settings.to_dict(),
		"alarms": alarm_dicts,
		"todos": todo_dicts,
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
			
	todos.clear()
	for d in parsed.get("todos", []):
		if typeof(d) == TYPE_DICTIONARY:
			todos.append(Todo.from_dict(d))
