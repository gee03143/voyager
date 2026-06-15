class_name Habit
extends RefCounted

var title: String = ""
var active_days: Array[bool] = [true, true, true, true, true, true, true]
var checks: Array[bool] = [false, false, false, false, false, false, false]

func to_dict() -> Dictionary:
	return {
		"title": title,
		"active_days": active_days.duplicate(),
		"checks": checks.duplicate(),
	}
	
static func from_dict(d: Dictionary) -> Habit:
	var h := Habit.new()
	h.title = str(d.get("title", ""))
	h.active_days = _bool7(d.get("active_days", []), true)
	h.checks = _bool7(d.get("checks", []), false)
	return h
	
static func _bool7(arr, fill: bool) -> Array[bool]:
	var out: Array[bool] = []
	for i in 7:
		out.append(bool(arr[i]) if (typeof(arr) == TYPE_ARRAY and i < arr.size()) else fill)
	return out
