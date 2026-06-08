class_name Pomodoro
extends Node

signal ticked(time_left: float)
signal segment_changed(index: int)
signal focus_finished
signal session_completed

enum SegmentType { FOCUS, SHORT_BREAK, LONG_BREAK }

@export_range(1, 3600) var focus_seconds: float = 25 * 60
@export_range(1, 3600) var short_break_seconds: float = 5 * 60
@export_range(1, 3600) var long_break_seconds: float = 15 * 60
@export_range(1, 12) var total_focus_count: int = 2

var segment_types: Array[int] = []
var index: int = 0
var started: bool = false
var finished: bool = false
var _countdown: CountDown

func _ready() -> void:
	_countdown = CountDown.new()
	add_child(_countdown)
	_countdown.ticked.connect(_on_countdown_ticked)
	_countdown.finished.connect(_on_countdown_finished)
	build_plan()
	
func build_plan() -> void:
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
	_load_segment(0, false)
	
func start() -> void:
	if not finished:
		started = true
		_countdown.start()
	
func pause() -> void:
	_countdown.pause()
	
func is_running() -> bool:
	return _countdown.is_running()
	
func reset() -> void:
	_countdown.pause()
	build_plan()

func skip() -> void:
	if not finished:
		_advance()
		
# --- UI 조회용 ---
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
	_countdown.configure(duration_of(segment_types[i]))
	if resume:
		_countdown.start()
	else:
		_countdown.pause()
	segment_changed.emit(i)

func _on_countdown_ticked(time_left: float) -> void:
	ticked.emit(time_left)

func _on_countdown_finished() -> void:
	_advance()

func _advance() -> void:
	if segment_types[index] == SegmentType.FOCUS:
		focus_finished.emit()         # 끝났든 건너뛰었든 채운 것으로 취급
	var next := index + 1
	if next >= segment_types.size():
		finished = true
		_countdown.pause()
		session_completed.emit()
	else:
		_load_segment(next, true)     # 항상 재생
