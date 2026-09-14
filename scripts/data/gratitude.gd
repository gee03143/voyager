class_name Gratitude
extends RefCounted

signal changed

# 감사 일지 — 하루 1건, 항목 개수 자유. gratitude.json
# entries: [{id, date_iso, items:[String, ...], ts}]
# 날짜 유일성은 뷰가 entry_for_date로 보장(모델은 미강제 — Journal이 중복을 모델에서 막지 않는 것과 동일 원칙)

# ⚠️ 색인은 아래 CRUD와 from_dict 안에서만 유지된다(docs/architecture/store-id-index.md).
var entries: Array = []
var _by_id: Dictionary = {}          # id → entries의 항목(같은 참조)

func add_entry(date_iso: String) -> int:
	var id := IdGen.fresh(_by_id)            # 색인이 곧 사용 중 id 집합이다
	var e := {"id": id, "date_iso": date_iso, "items": [], "ts": int(Time.get_unix_time_from_system())}
	entries.append(e)
	_by_id[id] = e
	changed.emit()
	return id

func update_entry(id: int, items: Array) -> void:
	var e = _by_id.get(id)
	if e == null:
		return
	var s: Array = []
	for it in items:
		s.append(str(it))
	e["items"] = s
	changed.emit()

func remove_entry(id: int) -> void:
	if not _by_id.has(id):
		return
	for i in entries.size():                 # 지우기는 드물다. 자리를 찾는 건 그대로 훑는다
		if int(entries[i].get("id", 0)) == id:
			entries.remove_at(i)
			break
	_by_id.erase(id)
	changed.emit()

# 날짜로 찾는 것은 하루에 한 번꼴이라 그대로 둔다. 색인은 id 전용이다.
func entry_for_date(date_iso: String) -> Dictionary:
	for e in entries:
		if str(e.get("date_iso", "")) == date_iso:
			return e
	return {}

func has_entry(id: int) -> bool:
	return _by_id.has(id)

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
	_reindex()

func _reindex() -> void:
	_by_id.clear()
	for e in entries:
		_by_id[int(e.get("id", 0))] = e
