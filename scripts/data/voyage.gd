class_name Voyage
extends RefCounted

signal changed

var total_play_seconds: float = 0.0
var total_focus_seconds: float = 0.0
var voyage_distance: float = 0.0    # 배가 항해한 누적 거리(감성용 — 속도 적분, 부정확 OK)

func add_focus(seconds: float) -> void:
	if seconds <= 0.0:
		return
	total_focus_seconds += seconds
	changed.emit()
	
func to_dict() -> Dictionary:
	return {
		"total_play_seconds": total_play_seconds,
		"total_focus_seconds": total_focus_seconds,
		"voyage_distance": voyage_distance,
	}
	
func from_dict(d: Dictionary) -> void:
	total_play_seconds = float(d.get("total_play_seconds", total_play_seconds))
	total_focus_seconds = float(d.get("total_focus_seconds", total_focus_seconds))
	voyage_distance = float(d.get("voyage_distance", voyage_distance))
