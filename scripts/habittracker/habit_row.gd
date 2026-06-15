class_name HabitRow
extends HBoxContainer

signal changed
signal delete_requested(row: HabitRow)

@onready var drag_handle: DragHandle = $DragHandle
@onready var name_edit: LineEdit = $NameEdit
@onready var cells_box: HBoxContainer = $CellsBox
@onready var delete_button: Button = $DeleteButton

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
		var cb := CheckBox.new()
		cb.toggled.connect(func(p): _on_cell_toggled(i, p))   # i는 생성 시점 값으로 캡처됨
		wrap.add_child(cb)
		cells_box.add_child(wrap)
		_cells.append(cb)
		
# Data -> UI
func setup(habit: Habit) -> void:
	name_edit.text = habit.title
	_active = habit.active_days.duplicate()
	_checks = habit.checks.duplicate()
	for i in 7:
		_cells[i].set_pressed_no_signal(_checks[i])

# UI -> Data
func get_data() -> Habit:
	var h := Habit.new()
	h.title = name_edit.text
	h.active_days = _active.duplicate()
	h.checks = _checks.duplicate()
	return h
	
func _on_cell_toggled(i: int, pressed: bool) -> void:
	_checks[i] = pressed
	changed.emit()
