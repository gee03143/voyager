extends Node

enum Kind { NONE, POMODORO, TIMER }

signal session_logged(event_id: int)   # 세션 완료 → 방금 적재된 이벤트 id (컴패니언 배선용)

# 세션 컨트롤러 — 진행 중 포모/타이머 인스턴스를 상주 소유(뷰와 분리).
# 휘발성(종료 시 소멸, Save 직렬화 X). Save는 앎(컨트롤러 계층).
var pomodoro: Pomodoro
var timer: SimpleTimer
var current_activity: String = ""   # 현재 집중 대상(Subject key, 휘발성)
var _pomo_start_ts: int = 0         # 세션 시작 벽시계 시각(휘발성) — 0 = 시작 기록 없음
var _timer_start_ts: int = 0

func _ready() -> void:
	pomodoro = Pomodoro.new()
	pomodoro.name = "Pomodoro"
	add_child(pomodoro)
	pomodoro.focus_seconds = Save.settings.focus_seconds
	pomodoro.short_break_seconds = Save.settings.short_break_seconds
	pomodoro.long_break_seconds = Save.settings.long_break_seconds
	pomodoro.total_focus_count = Save.settings.total_focus_count
	pomodoro.build_plan()
	pomodoro.focus_finished.connect(_on_focus_finished)
	pomodoro.session_started.connect(_on_session_started)
	pomodoro.session_completed.connect(_on_session_completed)
	
	timer = SimpleTimer.new()
	timer.name = "Timer"
	add_child(timer)
	timer.configure(Save.settings.timer_seconds)
	timer.timer_started.connect(_on_timer_started)
	timer.timer_finished.connect(_on_timer_finished)

func _on_session_started() -> void:
	_pomo_start_ts = int(Time.get_unix_time_from_system())

func _on_timer_started() -> void:
	_timer_start_ts = int(Time.get_unix_time_from_system())

func _on_focus_finished() -> void:
	Save.voyage.add_focus(pomodoro.focus_seconds)   # 집중 1구간 = 계획된 집중 길이 적립
	Save.lexicon.unlock_subject(current_activity)	# 집중 1구간 = 그 활동 했음 → 해금

func _on_timer_finished() -> void:
	Save.voyage.add_focus(timer.duration)
	Save.lexicon.unlock_subject(current_activity)
	var payload := {"seconds": int(timer.duration), "subject": current_activity}
	if _timer_start_ts > 0:
		payload["start_ts"] = _timer_start_ts
	_timer_start_ts = 0
	var id := Save.activity_log.add("timer", payload)
	session_logged.emit(id)
	Sound.play_set(Save.settings.sound_set)   # 완료음(컨트롤러가 완료를 앎)
	timer.reset()                             # 완주 → 자동 대기 복귀 (포모와 일관)

func _on_session_completed() -> void:
	var secs := int(pomodoro.focus_seconds * pomodoro.total_focus_count)
	var payload := {"focus_count": pomodoro.total_focus_count, "seconds": secs, "subject": current_activity}
	if _pomo_start_ts > 0:
		payload["start_ts"] = _pomo_start_ts
	_pomo_start_ts = 0
	var id := Save.activity_log.add("pomodoro_session", payload)
	session_logged.emit(id)
	Sound.play_set(Save.settings.sound_set)   # 완료음
	pomodoro.build_plan()                     # 완료 → 자동 대기 복귀
	
# --- active 세션 선택 (진행 중 = started & !finished, 포모 우선 → 타이머) ---
func active_kind() -> int:
	if pomodoro.started and not pomodoro.finished:
		return Kind.POMODORO
	if timer.started and not timer.finished:
		return Kind.TIMER
	return Kind.NONE

func is_active() -> bool:
	return active_kind() != Kind.NONE
	
func is_focusing() -> bool:
	if timer.is_running():
		return true
	return pomodoro.is_running() and pomodoro.segment_type_at(pomodoro.index) == Pomodoro.SegmentType.FOCUS

# --- 읽기 (HUD 폴링용) ---
func active_time_left() -> float:
	match active_kind():
		Kind.POMODORO: return pomodoro.time_left()
		Kind.TIMER: return timer.time_left()
	return 0.0

func active_total() -> float:
	match active_kind():
		Kind.POMODORO: return pomodoro.current_total()
		Kind.TIMER: return timer.duration
	return 0.0

func active_paused() -> bool:
	match active_kind():
		Kind.POMODORO: return not pomodoro.is_running()
		Kind.TIMER: return not timer.is_running()
	return false

# --- 제어 (HUD 버튼용) ---
func active_toggle() -> void:
	match active_kind():
		Kind.POMODORO:
			if pomodoro.is_running(): pomodoro.pause()
			else: pomodoro.start()
		Kind.TIMER:
			if timer.is_running(): timer.pause()
			else: timer.start()

func active_skip() -> void:
	if active_kind() == Kind.POMODORO:
		pomodoro.skip()

func active_reset() -> void:
	match active_kind():
		Kind.POMODORO: pomodoro.reset()
		Kind.TIMER: timer.reset()
