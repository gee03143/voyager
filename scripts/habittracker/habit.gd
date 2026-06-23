class_name Habit
extends RefCounted

var id: int = 0
var title: String = ""
var active_days: Array[bool] = [true, true, true, true, true, true, true]
var checks: Array[bool] = [false, false, false, false, false, false, false]

func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"active_days": active_days.duplicate(),
		"checks": checks.duplicate(),
	}
	
static func from_parts(p_id: int, def: Dictionary, checks_arr) -> Habit:
	var h := Habit.new()
	h.id = p_id
	h.title = str(def.get("title", ""))
	h.active_days = _bool7(def.get("active_days", []), true)
	h.checks = _bool7(checks_arr, false)
	return h
	
static func from_dict(d: Dictionary) -> Habit:
	var h := Habit.new()
	h.id = int(d.get("id", 0))
	h.title = str(d.get("title", ""))
	h.active_days = _bool7(d.get("active_days", []), true)
	h.checks = _bool7(d.get("checks", []), false)
	return h
	
static func _bool7(arr, fill: bool) -> Array[bool]:
	var out: Array[bool] = []
	for i in 7:
		out.append(bool(arr[i]) if (typeof(arr) == TYPE_ARRAY and i < arr.size()) else fill)
	return out
	
static func _generate_new_id() -> int:
	var used := {}
	for def in Save.habit_defs:
		used[int(def["id"])] = true
	for wk in Save.habit_weeks:
		for k in wk.get("checks", {}):
			used[int(k)] = true          # 과거 체크 키까지 포함해 절대 재사용 안 함
	return IdGen.fresh(used)
