class_name TodoRow
extends PanelContainer

signal changed
signal delete_requested(row: TodoRow)

@onready var done_check: CheckBox = $HBox/DoneCheck
@onready var text_edit: LineEdit = $HBox/TextEdit
@onready var delete_button: Button = $HBox/DeleteButton

func _ready() -> void:
	done_check.toggled.connect(_on_done_toggled)
	text_edit.text_changed.connect(func(_t): changed.emit())
	delete_button.pressed.connect(func(): delete_requested.emit(self))

# Data -> UI
func setup(todo: Todo) -> void:
	done_check.button_pressed = todo.done
	text_edit.text = todo.text
	_apply_done_style(todo.done)
	
# UI -> Data
func get_data() -> Todo:
	var t := Todo.new()
	t.done = done_check.button_pressed
	t.text = text_edit.text
	return t
	
func _on_done_toggled(pressed: bool) -> void:
	_apply_done_style(pressed)
	changed.emit()
	
func _apply_done_style(done: bool) -> void:
	text_edit.modulate = Color(1, 1, 1, 0.5) if done else Color(1, 1, 1, 1.0)
