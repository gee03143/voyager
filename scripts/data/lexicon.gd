class_name Lexicon
extends RefCounted

signal changed
signal subject_unlocked(key: String)

var subjects: Array = []   # 해금된 Subject key (영구, 안 줄어듦)

func unlock_subject(key: String) -> void:
	if key == "" or subjects.has(key):
		return
	subjects.append(key)
	changed.emit()
	subject_unlocked.emit(key)

func has_subject(key: String) -> bool:
	return subjects.has(key)

func to_dict() -> Dictionary:
	return {"subjects": subjects}

func from_dict(d: Dictionary) -> void:
	var s = d.get("subjects", [])
	subjects = s if typeof(s) == TYPE_ARRAY else []
