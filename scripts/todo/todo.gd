class_name Todo
extends RefCounted

var text: String = ""
var done: bool = false
var due_date: String = ""          # "YYYY-MM-DD", "" = 마감일 없음

func to_dict() -> Dictionary:
	return {
		"text": text, 
		"done": done,
		"due_date": due_date,
	}

static func from_dict(d: Dictionary) -> Todo:
	var t := Todo.new()
	t.text = str(d.get("text", ""))
	t.done = bool(d.get("done", false))
	t.due_date = str(d.get("due_date", ""))
	return t
