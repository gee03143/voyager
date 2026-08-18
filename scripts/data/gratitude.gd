class_name Gratitude
extends RefCounted

signal changed

# 감사 일지 — 하루 1건, 항목 개수 자유. gratitude.json
# entries: [{id, date_iso, items:[String, ...], ts}]
# 날짜 유일성은 뷰가 entry_for_date로 보장(모델은 미강제 — Journal이 중복을 모델에서 막지 않는 것과 동일 원칙)
var entries: Array = []

func add_entry(date_iso: String) -> int:
	var used := {}
	for e in entries:
		used[int(e.get("id", 0))] = true
	var id := IdGen.fresh(used)
	entries.append({"id": id, "date_iso": date_iso, "items": [], "ts": int(Time.get_unix_time_from_system())})
	changed.emit()
	return id

func update_entry(id: int, items: Array) -> void:
	for e in entries:
		if int(e.get("id", 0)) == id:
			var s: Array = []
			for it in items:
				s.append(str(it))
			e["items"] = s
			changed.emit()
			return

func remove_entry(id: int) -> void:
	for i in entries.size():
		if int(entries[i].get("id", 0)) == id:
			entries.remove_at(i)
			changed.emit()
			return

func entry_for_date(date_iso: String) -> Dictionary:
	for e in entries:
		if str(e.get("date_iso", "")) == date_iso:
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
				var raw = x.get("items", [])
				var items: Array = []
				if typeof(raw) == TYPE_ARRAY:
					for it in raw:
						items.append(str(it))
				x["items"] = items
				entries.append(x)
