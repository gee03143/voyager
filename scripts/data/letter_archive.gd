class_name LetterArchive
extends RefCounted

signal changed

var collected: Array = []   # [{id, template, slots}]  보관한 편지 (id=안정 randi)

func add(template: int, slots: Array) -> void:
	collected.append({"id": randi(), "template": template, "slots": slots})
	changed.emit()

func to_dict() -> Dictionary:
	return {"collected": collected}

func from_dict(d: Dictionary) -> void:
	var c = d.get("collected", [])
	collected = c if typeof(c) == TYPE_ARRAY else []
