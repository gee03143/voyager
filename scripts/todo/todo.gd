class_name Todo
extends RefCounted

var text: String = ""
var done: bool = false
var due_date: String = ""          # "YYYY-MM-DD", "" = 마감일 없음
var created_ts: int = 0            # 만든 시각(unix). 0 = 모름

func _init() -> void:
	created_ts = int(Time.get_unix_time_from_system())

func to_dict() -> Dictionary:
	return {
		"text": text, 
		"done": done,
		"due_date": due_date,
		"created_ts": created_ts,
	}

static func from_dict(d: Dictionary) -> Todo:
	var t := Todo.new()
	t.text = str(d.get("text", ""))
	t.done = bool(d.get("done", false))
	t.due_date = str(d.get("due_date", ""))
	t.created_ts = int(d.get("created_ts", 0))     # 키 없으면 0 = 모름
	return t
