class_name Journal
extends RefCounted

signal changed

# 사용자가 직접 쓴 자유 일지 — append 타임스탬프 노트
var notes: Array = []   # [{id, ts, text}]

func add(text: String) -> void:
	var used := {}
	for n in notes:
		used[int(n.get("id", 0))] = true
	notes.append({"id": IdGen.fresh(used), "ts": int(Time.get_unix_time_from_system()), "text": text})
	changed.emit()

func remove(id: int) -> void:
	for i in notes.size():
		if int(notes[i].get("id", 0)) == id:
			notes.remove_at(i)
			changed.emit()
			return

func to_dict() -> Dictionary:
	return {"notes": notes}

func from_dict(d: Dictionary) -> void:
	notes = []
	var raw = d.get("notes", [])
	if typeof(raw) == TYPE_ARRAY:
		for n in raw:
			if typeof(n) == TYPE_DICTIONARY:
				n["id"] = int(n.get("id", 0))     # float → int 정규화
				n["ts"] = int(n.get("ts", 0))
				notes.append(n)
