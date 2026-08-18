class_name GratitudeItemRow
extends HBoxContainer

signal text_changed(text: String)
signal delete_requested

@onready var item_edit: TextEdit = $ItemEdit
@onready var delete_button: Button = $DeleteButton

func _ready() -> void:
	item_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	item_edit.gui_input.connect(_on_item_edit_gui_input)
	item_edit.text_changed.connect(func(): text_changed.emit(item_edit.text))
	delete_button.pressed.connect(func(): delete_requested.emit())

func _on_item_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		if event.shift_pressed:
			item_edit.insert_text_at_caret("\n")
		else:
			item_edit.release_focus()

func set_text(t: String) -> void:
	item_edit.text = t

func get_text() -> String:
	return item_edit.text

func grab_edit_focus() -> void:
	item_edit.grab_focus()
