class_name GratitudeItemRow
extends HBoxContainer

signal text_changed(text: String)
signal delete_requested

@onready var item_edit: TextEdit = $ItemEdit
@onready var delete_button: Button = $DeleteButton

# 트리 진입 전파가 끝나기 전에 붙은 행은 _ready가 아직 안 돌아 @onready가 비어 있다.
# 값을 들고 있다가 _ready에서 적용한다.
var _text := ""

func _ready() -> void:
	item_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	item_edit.gui_input.connect(_on_item_edit_gui_input)
	item_edit.text_changed.connect(func(): text_changed.emit(item_edit.text))
	delete_button.pressed.connect(func(): delete_requested.emit())
	item_edit.text = _text

func _on_item_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		if event.shift_pressed:
			item_edit.insert_text_at_caret("\n")
		else:
			item_edit.release_focus()

func set_text(t: String) -> void:
	_text = t
	if is_node_ready():
		item_edit.text = t

func get_text() -> String:
	return item_edit.text if is_node_ready() else _text

func grab_edit_focus() -> void:
	item_edit.grab_focus()
