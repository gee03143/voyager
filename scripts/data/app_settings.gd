class_name AppSettings
extends RefCounted  #노드가 아닌 순수 데이터 객체(자동 메모리 관리)

# 포모 세션 설정
var focus_seconds: float = 25 * 60
var short_break_seconds: float = 5 * 60
var long_break_seconds: float = 15 * 60
var total_focus_count: int = 4

func to_dict() -> Dictionary:
	return {
		"focus_seconds": focus_seconds,
		"short_break_seconds": short_break_seconds,
		"long_break_seconds": long_break_seconds,
		"total_focus_count": total_focus_count,
	}

func from_dict(d: Dictionary) -> void:
	# 키 없으면 기본값 유지 → 스키마 진화에 안전
	focus_seconds = d.get("focus_seconds", focus_seconds)
	short_break_seconds = d.get("short_break_seconds", short_break_seconds)
	long_break_seconds = d.get("long_break_seconds", long_break_seconds)
	total_focus_count = max(1, int(d.get("total_focus_count", total_focus_count)))
