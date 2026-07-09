class_name TabNavSlot
extends HBoxContainer

signal tab_selected(index: int)

var _nav := ButtonGroupNav.new()

func set_tabs(labels: Array[String]) -> void:
	_clear_buttons()
	var buttons: Array = []
	for label in labels:
		var b := Button.new()
		b.text = label
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(b)
		buttons.append(b)
	_nav.setup(buttons, false)
	_nav.selected.connect(_on_selected)
	_nav.select(0)

func clear() -> void:
	for connection in tab_selected.get_connections():
		tab_selected.disconnect(connection["callable"])
	_clear_buttons()
	_nav = ButtonGroupNav.new()

func _clear_buttons() -> void:
	for child in get_children():
		child.queue_free()

func _on_selected(index: int) -> void:
	tab_selected.emit(index)
