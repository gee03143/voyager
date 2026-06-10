class_name Todo
extends RefCounted

var text: String = ""
var done: bool = false

func to_dict() -> Dictionary:
	return {
		"text": text, 
		"done": done,
	}

static func from_dict(d: Dictionary) -> Todo:
	var t := Todo.new()
	t.text = str(d.get("text", ""))
	t.done = bool(d.get("done", false))
	return t
