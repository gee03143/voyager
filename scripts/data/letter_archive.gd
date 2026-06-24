class_name LetterArchive
extends RefCounted

signal changed

# 편지 한 통(telegraphic): {id, template_idx, subject, fact, state, author, ts}
#   author "" = 내가 보낸 것 / 비어있지 않으면 받은 것(보낸 항해자 이름)
var entries: Array = []

func add(template_idx: int, subject: String, fact: String, state: String, author: String = "") -> int:
	var used := {}
	for e in entries:
		used[int(e.get("id", 0))] = true
	var id := IdGen.fresh(used)
	entries.append({
		"id": id, "template_idx": template_idx,
		"subject": subject, "fact": fact, "state": state,
		"author": author, "ts": int(Time.get_unix_time_from_system()),
	})
	changed.emit()
	return id

func sent() -> Array:        # 내가 보낸 것(author "")
	return entries.filter(func(e): return str(e.get("author", "")) == "")

func received() -> Array:    # 받아 보관한 것
	return entries.filter(func(e): return str(e.get("author", "")) != "")

func to_dict() -> Dictionary:
	return {"entries": entries}

func from_dict(d: Dictionary) -> void:
	entries = []
	var raw = d.get("entries", [])
	if typeof(raw) == TYPE_ARRAY:
		for x in raw:
			if typeof(x) == TYPE_DICTIONARY:
				x["id"] = int(x.get("id", 0))
				x["ts"] = int(x.get("ts", 0))
				x["template_idx"] = int(x.get("template_idx", 0))
				entries.append(x)
