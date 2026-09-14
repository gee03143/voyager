class_name Mood
extends RefCounted

signal changed

# 무드 기록 — 로그형, 하루 여러 건 허용. mood.json
# entries: [{id, ts, level(1~5), memo}]   level: 1=아주 나쁨 ~ 5=아주 좋음

# ⚠️ 색인은 아래 CRUD와 from_dict 안에서만 유지된다(docs/architecture/store-id-index.md).
var entries: Array = []
var _by_id: Dictionary = {}          # id → entries의 항목(같은 참조)

func add_entry(level: int, memo: String = "") -> int:
	var id := IdGen.fresh(_by_id)            # 색인이 곧 사용 중 id 집합이다
	var e := {"id": id, "ts": int(Time.get_unix_time_from_system()), "level": clampi(level, 1, 5), "memo": memo}
	entries.append(e)
	_by_id[id] = e
	changed.emit()
	return id

func update_entry(id: int, level: int, memo: String) -> void:
	var e = _by_id.get(id)
	if e == null:
		return
	e["level"] = clampi(level, 1, 5)
	e["memo"] = memo
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

func entry_by_id(id: int) -> Dictionary:
	var e = _by_id.get(id)
	return e if e != null else {}

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
	_reindex()

func _reindex() -> void:
	_by_id.clear()
	for e in entries:
		_by_id[int(e.get("id", 0))] = e
