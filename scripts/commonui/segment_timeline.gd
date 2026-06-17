class_name SegmentTimeline
extends Control

const GAP := 7.0
const FOCUS_W := 16.0
const BREAK_W := 10.0
const LONG_W := 14.0
const PIP_H := 12.0

const C_FOCUS_DONE := Color(0.54, 0.435, 0.227)
const C_FOCUS_CUR := Color(0.953, 0.788, 0.42)
const C_FOCUS_PEND := Color(0.5, 0.42, 0.27)
const C_BREAK_DONE := Color(0.27, 0.376, 0.435)
const C_BREAK_PEND := Color(0.247, 0.322, 0.373)
const C_CUR_OUTLINE := Color(0.984, 0.914, 0.74)

var _types: Array = []
var _index: int = 0
var _finished: bool = false

func render(types: Array, index: int, finished: bool) -> void:
	_types = types
	_index = index
	_finished = finished
	queue_redraw()

func _pip_w(type: int) -> float:
	match type:
		Pomodoro.SegmentType.FOCUS:
			return FOCUS_W
		Pomodoro.SegmentType.LONG_BREAK:
			return LONG_W
	return BREAK_W

func _draw() -> void:
	if _types.is_empty():
		return
	var natural := 0.0
	for t in _types:
		natural += _pip_w(t)
	natural += GAP * (_types.size() - 1)
	var scale := minf(1.0, size.x / natural) if natural > 0.0 else 1.0   # 넘치면 축소, 모자라면 1
	var gap := GAP * scale
	var x := (size.x - natural * scale) * 0.5                             # 가운데 정렬
	var cy := size.y * 0.5
	for i in _types.size():
		var t: int = _types[i]
		var w := _pip_w(t) * scale
		var rect := Rect2(x, cy - PIP_H * 0.5, w, PIP_H)
		var is_focus := t == Pomodoro.SegmentType.FOCUS
		if _finished or i < _index:
			draw_rect(rect, C_FOCUS_DONE if is_focus else C_BREAK_DONE, true)
		elif i == _index:
			draw_rect(rect, C_FOCUS_CUR if is_focus else C_BREAK_DONE, true)
			draw_rect(rect, C_CUR_OUTLINE, false, 1.3)
		else:
			draw_rect(rect, C_FOCUS_PEND if is_focus else C_BREAK_PEND, false, 1.2)
		x += w + gap
