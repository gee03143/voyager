class_name ActivityLog
extends RefCounted

signal changed

# 자동 수집 완료 활동 스트림 (append, 안정 id + 벽시계 ts)
# type: "todo"{title} | "pomodoro_session"{focus_count, seconds} | "timer"{seconds}
# habit 완료는 여기 저장 X — habit_weeks에서 파생(단일 진실)
var events: Array = []     # [{id, type, ts, ...payload}]
var play_days: Dictionary = {}

func add(type: String, payload: Dictionary = {}) -> void:
	var used := {}
	for e in events:
		used[int(e.get("id", 0))] = true
	var ev := {"id": IdGen.fresh(used), "type": type, "ts": int(Time.get_unix_time_from_system())}
	ev.merge(payload)
	events.append(ev)
	changed.emit()
	
func add_play(day_iso: String, seconds: float) -> void:
	if seconds <= 0.0:
		return
	play_days[day_iso] = float(play_days.get(day_iso, 0.0)) + seconds

func to_dict() -> Dictionary:
	return {
		"events": events,
		"play_days": play_days
	}

func from_dict(d: Dictionary) -> void:
	events = []
	var raw = d.get("events", [])
	if typeof(raw) == TYPE_ARRAY:
		for e in raw:
			if typeof(e) == TYPE_DICTIONARY:
				e["id"] = int(e.get("id", 0))      # JSON 로드 시 float → int 정규화
				e["ts"] = int(e.get("ts", 0))
				events.append(e)
	var pd = d.get("play_days", {})
	play_days = pd if typeof(pd) == TYPE_DICTIONARY else {}
