class_name ActivityLog
extends RefCounted

signal changed

# 자동 수집 완료 활동 스트림 (append, 안정 id + 벽시계 ts)
# type: "todo"{title} | "pomodoro_session"{focus_count, seconds, start_ts} | "timer"{seconds, start_ts}
# ts = 완료 시각. start_ts = 시작 시각(세션 계열만) — 없으면 순간 이벤트
# note = 사용자가 붙인 짧은 회고(선택). 자동 수집분과 달리 사용자 편집 대상 — 통계 계산엔 안 씀
# habit 완료는 여기 저장 X — habit_weeks에서 파생(단일 진실). 파생분은 id가 없어 노트 대상 아님
var events: Array = []     # [{id, type, ts, ...payload}]
var play_days: Dictionary = {}

func add(type: String, payload: Dictionary = {}) -> int:
	var used := {}
	for e in events:
		used[int(e.get("id", 0))] = true
	var id := IdGen.fresh(used)
	var ev := {"id": id, "type": type, "ts": int(Time.get_unix_time_from_system())}
	ev.merge(payload)
	events.append(ev)
	changed.emit()
	return id
	
func note_of(id: int) -> String:
	var e := _find(id)
	return str(e.get("note", "")) if not e.is_empty() else ""

func set_note(id: int, text: String) -> void:
	var e := _find(id)
	if e.is_empty():
		return
	var t := text.strip_edges()
	if t == str(e.get("note", "")):
		return                       # 값 동일 → 저장 트리거 안 함(자동 저장이라 호출이 잦음)
	if t == "":
		e.erase("note")              # 빈 노트는 키째 제거 — start_ts와 같은 원칙
	else:
		e["note"] = t
	changed.emit()

func _find(id: int) -> Dictionary:
	if id == 0:
		return {}                    # 0 = IdGen이 제외하는 값 + 습관 파생 이벤트엔 id 키 자체가 없음
	for e in events:
		if int(e.get("id", 0)) == id:
			return e
	return {}
	
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
				if e.has("start_ts"):              # 세션 계열만 보유 — 없는 이벤트는 키를 만들지 않음
					e["start_ts"] = int(e["start_ts"])
				if e.has("note"):
					e["note"] = str(e["note"])
				events.append(e)
	var pd = d.get("play_days", {})
	play_days = pd if typeof(pd) == TYPE_DICTIONARY else {}

func event_by_id(id: int) -> Dictionary:
	return _find(id)             # 참조 반환 — 쓰기는 set_note()로만(직접 쓰면 changed가 안 나감)
