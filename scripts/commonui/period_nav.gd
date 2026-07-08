class_name PeriodNav
extends Node

enum Unit { WEEK, MONTH }

const CURRENT_PREFIX := {
	Unit.WEEK: "이번 주",
	Unit.MONTH: "이번 달",
}

signal refresh_requested

@export var prev_button: BaseButton
@export var next_button: BaseButton
@export var reset_button: BaseButton
@export var label: Label
@export var unit: Unit = Unit.WEEK

var _start: String = ""
var _valid_starts: Array[String] = []   # 비어있으면 산술 계산, 있으면 이 목록 안에서만 이동

func _ready() -> void:
	if prev_button != null:
		prev_button.pressed.connect(func(): _step(-1))
	if next_button != null:
		next_button.pressed.connect(func(): _step(1))
	if reset_button != null:
		reset_button.pressed.connect(func(): _step(0))
	_start = _default_start()
	_update()

func current_start() -> String:
	return _start
	
func _default_start() -> String:
	return DateUtil.month_start_iso() if unit == Unit.MONTH else DateUtil.monday_iso()
	
func set_valid_starts(starts: Array[String]) -> void:
	_valid_starts = starts
	_start = _valid_starts[-1] if not _valid_starts.is_empty() else _default_start()
	_update()

func _step(direction: int) -> void:
	if not _valid_starts.is_empty():
		_step_list(direction)
	else:
		_step_arithmetic(direction)
	_update()
	refresh_requested.emit()

func _step_list(direction: int) -> void:
	if direction == 0:
		_start = _valid_starts[-1]
		return
	var idx := _valid_starts.find(_start)
	if idx == -1:
		idx = _valid_starts.size() - 1
	_start = _valid_starts[clampi(idx + direction, 0, _valid_starts.size() - 1)]

func _step_arithmetic(direction: int) -> void:
	if direction == 0:
		_start = _default_start()
	elif unit == Unit.MONTH:
		_start = DateUtil.add_months(_start, direction)
	else:
		_start = DateUtil.add_days(_start, direction * 7)
	var default_start := _default_start()
	if _start > default_start:
		_start = default_start

func _update() -> void:
	var is_current: bool
	var is_at_start := false
	if not _valid_starts.is_empty():
		var idx := _valid_starts.find(_start)
		is_current = idx == _valid_starts.size() - 1
		is_at_start = idx <= 0
	else:
		is_current = _start == _default_start()
	var range_text := DateUtil.month_label(_start) if unit == Unit.MONTH else DateUtil.week_range_label(_start)
	if label != null:
		label.text = ("%s (%s)" % [CURRENT_PREFIX[unit], range_text]) if is_current else range_text
	if next_button != null:
		next_button.disabled = is_current
	if prev_button != null:
		prev_button.disabled = is_at_start
