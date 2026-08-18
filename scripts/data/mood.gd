class_name Mood
extends RefCounted

signal changed

# 무드 기록 — 로그형, 하루 여러 건 허용. mood.json
# entries: [{id, ts, level(1~5), memo}]   level: 1=아주 나쁨 ~ 5=아주 좋음
var entries: Array = []

func add_entry(level: int, memo: String = "") -> int:
	var used := {}
	for e in entries:
		used[int(e.get("id", 0))] = true
	var id := IdGen.fresh(used)
	entries.append({"id": id, "ts": int(Time.get_unix_time_from_system()), "level": clampi(level, 1, 5), "memo": memo})
	changed.emit()
	return id

func update_entry(id: int, level: int, memo: String) -> void:
	for e in entries:
		if int(e.get("id", 0)) == id:
			e["level"] = clampi(level, 1, 5)
			e["memo"] = memo
			changed.emit()
			return

func remove_entry(id: int) -> void:
	for i in entries.size():
		if int(entries[i].get("id", 0)) == id:
			entries.remove_at(i)
			changed.emit()
			return

func entry_by_id(id: int) -> Dictionary:
	for e in entries:
		if int(e.get("id", 0)) == id:
			return e
	return {}

func to_dict() -> Dictionary:
	return {"entries": entries}

func from_dict(d: Dictionary) -> void:
	entries = []
	var re = d.get("entries", [])
	if typeof(re) == TYPE_ARRAY:
		for x in re:
			if typeof(x) == TYPE_DICTIONARY:
				x["id"] = int(x.get("id", 0))
				x["ts"] = int(x.get("ts", 0))
				x["level"] = clampi(int(x.get("level", 3)), 1, 5)
				x["memo"] = str(x.get("memo", ""))
				entries.append(x)
