class_name Pomodoro
extends Node

signal segment_changed(index: int)
signal focus_finished
signal session_completed
signal plan_built

enum SegmentType { FOCUS, SHORT_BREAK, LONG_BREAK }

@export_range(1, 3600) var focus_seconds: float = 25 * 60
@export_range(1, 3600) var short_break_seconds: float = 5 * 60
@export_range(1, 3600) var long_break_seconds: float = 15 * 60
@export_range(1, 12) var total_focus_count: int = 2

var segment_types: Array[int] = []
var index: int = 0
var started: bool = false
var finished: bool = false
var _handle: TimerHandle = null

func build_plan() -> void:
	_clear_handle()
	segment_types.clear()
	for i in total_focus_count:
		segment_types.append(SegmentType.FOCUS)
		var is_last := i == total_focus_count - 1
		if not is_last:
			segment_types.append(SegmentType.SHORT_BREAK)
		else:
			segment_types.append(SegmentType.LONG_BREAK)
	index = 0
	started = false
	finished = false
	if segment_types.is_empty():
		finished = true
		return
	plan_built.emit()
	_load_segment(0, false)

func start() -> void:
	if finished:
		return
	started = true
	if _handle == null or not _handle.is_valid():
		_start_segment_timer()      # 첫 시작(standby)
	elif _handle.is_paused():
		_handle.resume()            # 일시정지 → 재개

func pause() -> void:
	if _handle != null and _handle.is_valid() and not _handle.is_paused():
		_handle.pause()

func is_running() -> bool:
	return _handle != null and _handle.is_valid() and not _handle.is_paused()

func reset() -> void:
	build_plan()                    # build_plan 이 핸들도 정리

func skip() -> void:
	if not finished:
		_advance()

# --- UI 조회용 ---
func time_left() -> float:
	if _handle != null and _handle.is_valid():
		return _handle.remaining()
	if finished or segment_types.is_empty():
		return 0.0
	return duration_of(segment_types[index])      # standby = 해당 구간 전체 길이

func segment_count() -> int:
	return segment_types.size()

func segment_type_at(i: int) -> int:
	return segment_types[i]

func duration_of(type: int) -> float:
	match type:
		SegmentType.FOCUS:
			return focus_seconds
		SegmentType.SHORT_BREAK:
			return short_break_seconds
		SegmentType.LONG_BREAK:
			return long_break_seconds
	return focus_seconds

# --- 내부 ---
func _load_segment(i: int, resume: bool) -> void:
	index = i
	_clear_handle()
	if resume:
		_start_segment_timer()
	segment_changed.emit(i)

func _start_segment_timer() -> void:
	_handle = Timers.set_timer(duration_of(segment_types[index]), _on_segment_finished)

func _clear_handle() -> void:
	if _handle != null:
		if _handle.is_valid():
			_handle.cancel()
		_handle = null

func _on_segment_finished() -> void:
	_handle = null                  # 만료 핸들은 매니저가 이미 제거
	_advance()

func _advance() -> void:
	if segment_types[index] == SegmentType.FOCUS:
		focus_finished.emit()       # 끝났든 건너뛰었든 채운 것으로 취급
	var next := index + 1
	if next >= segment_types.size():
		finished = true
		_clear_handle()
		session_completed.emit()
	else:
		_load_segment(next, true)   # 항상 재생
