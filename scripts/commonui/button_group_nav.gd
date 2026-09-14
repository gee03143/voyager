class_name ButtonGroupNav
extends RefCounted

signal selected(index: int)

var _group := ButtonGroup.new()
var _buttons: Array[BaseButton] = []
var _current_index := -1
var _fill_sec := 0.0        # 0 = 선택 채움 안 씀. 값 고르기 성격의 묶음은 켜지 않는다
var _fill_dir := 0          # SelectionFill.Dir

# fill_sec을 주면 선택 표시가 즉시 바뀌지 않고 쓸어 들어온다.
func setup(buttons: Array, allow_close: bool = false, fill_sec: float = 0.0,
		fill_dir: int = SelectionFill.Dir.LEFT_TO_RIGHT) -> void:
	_group.allow_unpress = allow_close
	_fill_sec = fill_sec
	_fill_dir = fill_dir
	_buttons.clear()
	for b in buttons:
		var btn := b as BaseButton
		if btn == null:
			continue
		btn.toggle_mode = true
		btn.button_group = _group
		btn.toggled.connect(_on_toggled.bind(_buttons.size()))
		_buttons.append(btn)
		if _fill_sec > 0.0:
			SelectionFill.attach(btn, _fill_dir)
	if not _group.pressed.is_connected(_on_group_pressed):
		_group.pressed.connect(_on_group_pressed)

func setup_from(container: Node, allow_close: bool = false, fill_sec: float = 0.0,
		fill_dir: int = SelectionFill.Dir.LEFT_TO_RIGHT) -> void:   # 컨테이너의 BaseButton 자식들을 순서대로
	var buttons: Array = []
	for child in container.get_children():
		if child is BaseButton:
			buttons.append(child)
	setup(buttons, allow_close, fill_sec, fill_dir)

func _on_group_pressed(button: BaseButton) -> void:
	var index := _buttons.find(button)
	if index == _current_index:          # 이미 활성인 버튼 재클릭 → _on_toggled 쪽이 처리
		return
	_current_index = index
	_apply_fill()
	selected.emit(_buttons.find(button))

func _on_toggled(pressed: bool, index: int) -> void:
	if not pressed and not _any_pressed():
		_current_index = -1
		_apply_fill()
		selected.emit(-1)

# 고른 버튼만 채우고 나머지는 즉시 비운다.
func _apply_fill() -> void:
	if _fill_sec <= 0.0:
		return
	for i in _buttons.size():
		SelectionFill.set_selected(_buttons[i], i == _current_index, _fill_sec)

func _any_pressed() -> bool:
	for b in _buttons:
		if b.button_pressed:
			return true
	return false

func select(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	_current_index = index
	_buttons[index].set_pressed_no_signal(true)   # 시각 토글만, 신호는 직접
	_apply_fill()
	selected.emit(index)
