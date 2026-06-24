class_name Journal
extends RefCounted

signal changed

# 자유 일지 — 그룹(정의) + 문서(평평). records.json
# groups: [{id, name}]                         그룹 정의(안정 randi id). group_id 0 = 그룹 없음
# docs:   [{id, title, body, group_id, ts}]    평평한 문서, ts = 작성 unix
var groups: Array = []
var docs: Array = []

# --- 문서 CRUD ---
func add_doc(group_id: int = 0) -> int:
	var used := {}
	for d in docs:
		used[int(d.get("id", 0))] = true
	var id := IdGen.fresh(used)
	docs.append({"id": id, "title": "", "body": "", "group_id": group_id, "ts": int(Time.get_unix_time_from_system())})
	changed.emit()
	return id

func update_doc(id: int, title: String, body: String, group_id: int) -> void:
	for d in docs:
		if int(d.get("id", 0)) == id:
			d["title"] = title
			d["body"] = body
			d["group_id"] = group_id
			changed.emit()
			return

func remove_doc(id: int) -> void:
	for i in docs.size():
		if int(docs[i].get("id", 0)) == id:
			docs.remove_at(i)
			changed.emit()
			return

func doc_title(id: int) -> String:
	for d in docs:
		if int(d.get("id", 0)) == id:
			var t := str(d.get("title", "")).strip_edges()
			return t if t != "" else "(제목 없음)"
	return ""        # 없음 = 삭제됨

# --- 그룹 CRUD ---
func add_group(name: String) -> int:
	var used := {}
	for g in groups:
		used[int(g.get("id", 0))] = true
	var id := IdGen.fresh(used)
	groups.append({"id": id, "name": name})
	changed.emit()
	return id

func rename_group(id: int, name: String) -> void:
	for g in groups:
		if int(g.get("id", 0)) == id:
			g["name"] = name
			changed.emit()
			return

func remove_group(id: int) -> void:
	for i in groups.size():
		if int(groups[i].get("id", 0)) == id:
			groups.remove_at(i)
			break
	for d in docs:                       # 속한 문서는 미분류(0)로
		if int(d.get("group_id", 0)) == id:
			d["group_id"] = 0
	changed.emit()

func group_name(id: int) -> String:
	for g in groups:
		if int(g.get("id", 0)) == id:
			return str(g.get("name", ""))
	return ""

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
