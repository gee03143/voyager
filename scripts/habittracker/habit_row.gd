class_name HabitRow
extends HBoxContainer

signal changed
signal delete_requested(row: HabitRow)

@onready var drag_handle: DragHandle = $DragHandle
@onready var name_edit: LineEdit = $NameEdit
@onready var cells_box: HBoxContainer = $CellsBox
@onready var delete_button: Button = $DeleteButton

var _id: int = 0
var _active: Array[bool] = [true, true, true, true, true, true, true]
var _checks: Array[bool] = [false, false, false, false, false, false, false]
var _cells: Array[CheckBox] = []

func _ready() -> void:
	drag_handle.custom_minimum_size.x = HabitGrid.HANDLE_W
	drag_handle.row = self
	drag_handle.token = &"habit"
	name_edit.custom_minimum_size.x = HabitGrid.NAME_W
	name_edit.text_changed.connect(func(_t): changed.emit())
	delete_button.pressed.connect(func(): delete_requested.emit(self))
	_build_cells()

func _build_cells() -> void:
	for i in 7:
		var wrap := CenterContainer.new()
		wrap.custom_minimum_size.x = HabitGrid.DAY_W
		wrap.mouse_filter = Control.MOUSE_FILTER_STOP
		wrap.gui_input.connect(func(e): _on_cell_input(i, e)) # 입력은 cell이 처리
		var cb := CheckBox.new()
		cb.mouse_filter = Control.MOUSE_FILTER_IGNORE    # Checkbbox는 표시만
		wrap.add_child(cb)
		cells_box.add_child(wrap)
		_cells.append(cb)
		
func is_active(d: int) -> bool: return _active[d]
func is_checked(d: int) -> bool: return _checks[d]
		
# Data -> UI
func setup(habit: Habit) -> void:
	_id = habit.id
	name_edit.text = habit.title
	_active = habit.active_days.duplicate()
	_checks = habit.checks.duplicate()
	for i in 7:
		_render_cell(i)

# UI -> Data
func get_data() -> Habit:
	var h := Habit.new()
	h.id = _id
	h.title = name_edit.text
	h.active_days = _active.duplicate()
	h.checks = _checks.duplicate()
	return h
	
func _on_cell_input(i: int, event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if _active[i]:                       # 활성 칸만 완료 토글
			_checks[i] = not _checks[i]
			_render_cell(i)
			changed.emit()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_active[i] = not _active[i]          # 우클릭 = 활성/비활성 토글
		_render_cell(i)
		changed.emit()

func _render_cell(i: int) -> void:
	var cb := _cells[i]
	cb.set_pressed_no_signal(_checks[i] and _active[i])
	cb.disabled = not _active[i]             # 비활성 = 회색 비활성 모양
	cb.modulate.a = 1.0 if _active[i] else 0.4
	var wrap := cb.get_parent() as Control
	wrap.tooltip_text = TranslationServer.translate("HABIT_DAY_TOGGLE_OFF" if _active[i] else "HABIT_DAY_TOGGLE_ON")
