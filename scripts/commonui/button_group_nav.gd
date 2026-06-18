class_name ButtonGroupNav
extends RefCounted

signal selected(index: int)

var _group := ButtonGroup.new()
var _buttons: Array[BaseButton] = []

func setup(buttons: Array, allow_close: bool = false) -> void:
	_group.allow_unpress = allow_close
	_buttons.clear()
	for b in buttons:
		var btn := b as BaseButton
		if btn == null:
			continue
		btn.toggle_mode = true
		btn.button_group = _group
		btn.toggled.connect(_on_toggled.bind(_buttons.size()))
		_buttons.append(btn)
	if not _group.pressed.is_connected(_on_group_pressed):
		_group.pressed.connect(_on_group_pressed)

func setup_from(container: Node, allow_close: bool = false) -> void:        # 컨테이너의 BaseButton 자식들을 순서대로
	var buttons: Array = []
	for child in container.get_children():
		if child is BaseButton:
			buttons.append(child)
	setup(buttons, allow_close)


func _on_group_pressed(button: BaseButton) -> void:
	selected.emit(_buttons.find(button))

func _on_toggled(pressed: bool, index: int) -> void:
	if not pressed and not _any_pressed():
		selected.emit(-1)         	

func _any_pressed() -> bool:
	for b in _buttons:
		if b.button_pressed:
			return true
	return false

func select(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	_buttons[index].set_pressed_no_signal(true)   # 시각 토글만, 신호는 직접
	selected.emit(index)
