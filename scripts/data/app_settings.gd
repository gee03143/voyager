class_name AppSettings
extends RefCounted

signal changed                          # 설정 변경 → 저장 + 뷰 전파

# 포모 세션 설정
var focus_seconds: float = 25 * 60
var short_break_seconds: float = 5 * 60
var long_break_seconds: float = 15 * 60
var total_focus_count: int = 4
var timer_seconds: float = 5 * 60

# 시계 탭 공통 세팅
var hide_countdown: bool = false        # 카운트다운 숨기기
var auto_minimize: bool = true         # 활성 시 자동 최소화 (플래그만, 효과는 Week 7)
var sound_set: int = 0                 # 알람 소리 종류

func to_dict() -> Dictionary:
	return {
		"focus_seconds": focus_seconds,
		"short_break_seconds": short_break_seconds,
		"long_break_seconds": long_break_seconds,
		"total_focus_count": total_focus_count,
		"timer_seconds": timer_seconds,
		"hide_countdown": hide_countdown,
		"auto_minimize": auto_minimize,
		"sound_set": sound_set,
	}

func from_dict(d: Dictionary) -> void:
	# 키 없으면 기본값 유지 → 스키마 진화에 안전
	focus_seconds = d.get("focus_seconds", focus_seconds)
	short_break_seconds = d.get("short_break_seconds", short_break_seconds)
	long_break_seconds = d.get("long_break_seconds", long_break_seconds)
	total_focus_count = max(1, int(d.get("total_focus_count", total_focus_count)))
	timer_seconds = d.get("timer_seconds", timer_seconds)
	hide_countdown = bool(d.get("hide_countdown", hide_countdown))
	auto_minimize = bool(d.get("auto_minimize", auto_minimize))
	sound_set = int(d.get("sound_set", sound_set))
