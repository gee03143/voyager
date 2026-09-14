class_name Journal
extends RefCounted

signal changed

# 자유 일지 — 그룹(정의) + 문서(평평). records.json
# groups: [{id, name}]                         그룹 정의(안정 randi id). group_id 0 = 그룹 없음
# docs:   [{id, title, body, group_id, ts}]    평평한 문서, ts = 작성 unix

# id로 찾는 호출이 잦고 항목 수는 사용 기간에 비례해 는다. 배열을 훑으면 그 비용이
# 부르는 쪽의 이벤트 수와 곱해져 제곱이 된다(docs/architecture/store-id-index.md).
# ⚠️ 색인은 아래 CRUD와 from_dict 안에서만 유지된다. 바깥에서 배열을 통째로 갈아끼우거나
#    직접 넣고 빼면 색인이 어긋난다.
var groups: Array = []
var docs: Array = []
var _doc_by_id: Dictionary = {}      # id → docs의 항목(같은 참조)
var _group_by_id: Dictionary = {}    # id → groups의 항목(같은 참조)

# --- 문서 CRUD ---
func add_doc(group_id: int = 0) -> int:
	var id := IdGen.fresh(_doc_by_id)        # 색인이 곧 사용 중 id 집합이다
	var doc := {"id": id, "title": "", "body": "", "group_id": group_id, "ts": int(Time.get_unix_time_from_system())}
	docs.append(doc)
	_doc_by_id[id] = doc
	changed.emit()
	return id

func update_doc(id: int, title: String, body: String, group_id: int) -> void:
	var d = _doc_by_id.get(id)
	if d == null:
		return
	d["title"] = title
	d["body"] = body
	d["group_id"] = group_id
	changed.emit()

func remove_doc(id: int) -> void:
	if not _doc_by_id.has(id):
		return
	for i in docs.size():                    # 지우기는 드물다. 자리를 찾는 건 그대로 훑는다
		if int(docs[i].get("id", 0)) == id:
			docs.remove_at(i)
			break
	_doc_by_id.erase(id)
	changed.emit()

func has_doc(id: int) -> bool:
	return _doc_by_id.has(id)

func doc_title(id: int) -> String:
	var d = _doc_by_id.get(id)
	if d == null:
		return ""        # 없음 = 삭제됨
	var t := str(d.get("title", "")).strip_edges()
	return t if t != "" else "(제목 없음)"

# --- 그룹 CRUD ---
func add_group(name: String) -> int:
	var id := IdGen.fresh(_group_by_id)
	var g := {"id": id, "name": name}
	groups.append(g)
	_group_by_id[id] = g
	changed.emit()
	return id

func rename_group(id: int, name: String) -> void:
	var g = _group_by_id.get(id)
	if g == null:
		return
	g["name"] = name
	changed.emit()

func remove_group(id: int) -> void:
	if _group_by_id.has(id):
		for i in groups.size():
			if int(groups[i].get("id", 0)) == id:
				groups.remove_at(i)
				break
		_group_by_id.erase(id)
	for d in docs:                       # 속한 문서는 미분류(0)로
		if int(d.get("group_id", 0)) == id:
			d["group_id"] = 0
	changed.emit()

func group_name(id: int) -> String:
	var g = _group_by_id.get(id)
	return str(g.get("name", "")) if g != null else ""

# --- 직렬화 (id/group_id/ts int 정규화) ---
func to_dict() -> Dictionary:
	return {"groups": groups, "docs": docs}

func from_dict(d: Dictionary) -> void:
	groups = []
	var rg = d.get("groups", [])
	if typeof(rg) == TYPE_ARRAY:
		for g in rg:
			if typeof(g) == TYPE_DICTIONARY:
				g["id"] = int(g.get("id", 0))
				groups.append(g)
	docs = []
	var rd = d.get("docs", [])
	if typeof(rd) == TYPE_ARRAY:
		for x in rd:
			if typeof(x) == TYPE_DICTIONARY:
				x["id"] = int(x.get("id", 0))
				x["group_id"] = int(x.get("group_id", 0))
				x["ts"] = int(x.get("ts", 0))
				docs.append(x)
	_reindex()

func _reindex() -> void:
	_doc_by_id.clear()
	for d in docs:
		_doc_by_id[int(d.get("id", 0))] = d
	_group_by_id.clear()
	for g in groups:
		_group_by_id[int(g.get("id", 0))] = g
