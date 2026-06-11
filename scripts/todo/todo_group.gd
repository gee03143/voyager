class_name TodoGroup
extends RefCounted

var name: String = "기본"
var sort_key: int = 0
var sort_desc: bool = false
var tasks: Array[Todo] = []

func to_dict() -> Dictionary:
	var task_dicts := []
	for t in tasks:
		task_dicts.append(t.to_dict())
	return {
		"name": name,
		"sort_key": sort_key,
		"sort_desc": sort_desc,
		"tasks": task_dicts,
	}

static func from_dict(d: Dictionary) -> TodoGroup:
	var g := TodoGroup.new()
	g.name = str(d.get("name", "기본"))
	g.sort_key = int(d.get("sort_key", 0))
	g.sort_desc = bool(d.get("sort_desc", false))
	g.tasks.clear()
	for td in d.get("tasks", []):
		if typeof(td) == TYPE_DICTIONARY:
			g.tasks.append(Todo.from_dict(td))
	return g
