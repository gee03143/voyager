class_name TabNavSlot
extends HBoxContainer

signal tab_selected(index: int)

# 사이드바 nav(0.18)보다 짧다. 바뀌는 영역이 작고, 중앙에서 퍼지면 절반 거리만 가므로
# 같은 시간이어도 더 빠르게 읽힌다. F6에서 눈으로 조정할 값.
const FILL_SEC := 0.14

var _nav := ButtonGroupNav.new()

func set_tabs(labels: Array[String]) -> void:
	_clear_buttons()
	var buttons: Array = []
	for label in labels:
		var b := Button.new()
		b.text = tr(label)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(b)
		buttons.append(b)
	_nav.setup(buttons, false, FILL_SEC, SelectionFill.Dir.CENTER_OUT)
	_nav.selected.connect(_on_selected)
	_nav.select(0)

func clear() -> void:
	for connection in tab_selected.get_connections():
		tab_selected.disconnect(connection["callable"])
	_clear_buttons()
	_nav = ButtonGroupNav.new()

func _clear_buttons() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _on_selected(index: int) -> void:
	tab_selected.emit(index)
