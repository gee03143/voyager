class_name HabitRow
extends HBoxContainer

signal changed
signal delete_requested(row: HabitRow)

@onready var drag_handle: DragHandle = $DragHandle
@onready var name_edit: LineEdit = $NameEdit
@onready var cells_box: HBoxContainer = $CellsBox
@onready var delete_button: Button = $DeleteButton

const CELL_SIZE := Vector2(20, 20)
const CELL_POP_SEC := 0.18      # 눌린 감각만 주면 되므로 짧다. F6에서 눈으로 조정할 값
const CELL_POP_SCALE := 1.25    # 20px짜리 작은 표적이라 이만큼은 키워야 눈에 잡힌다
const CELL_FILL_SEC := 0.16     # 색이 스며드는 시간. 팝보다 짧아 색이 먼저 자리를 잡는다

var _id: int = 0
var _active: Array[bool] = [true, true, true, true, true, true, true]
var _checks: Array[bool] = [false, false, false, false, false, false, false]
var _wraps: Array[Control] = []
var _bases: Array[Panel] = []
var _fills: Array[Panel] = []
var _pop_tweens: Array[Tween] = []    # 칸마다 따로 — 공유하면 다른 칸을 누를 때 앞 칸이 커진 채로 남는다
var _fill_tweens: Array[Tween] = []   # 팝과 따로 — 한 트윈에 묶으면 chain이 느린 쪽을 기다려 팝이 중간에 멈춘다

func _ready() -> void:
	drag_handle.custom_minimum_size.x = HabitGrid.HANDLE_W
	drag_handle.row = self
	drag_handle.token = &"habit"
	name_edit.custom_minimum_size.x = HabitGrid.NAME_W
	name_edit.text_changed.connect(func(_t): changed.emit())
	delete_button.pressed.connect(func(): delete_requested.emit(self))
	_build_cells()

# 칸은 세 겹이다.
#   wrap(CenterContainer) — 입력을 받고 칸을 가운데 둔다
#   box(Control)          — 크기 고정 래퍼. 컨테이너는 자식의 scale을 되돌리므로 한 겹 끼운다
#   base/fill(Panel)      — 아래는 빈 칸, 위는 채운 칸. 알파로 겹쳐 색이 스며들게 한다
func _build_cells() -> void:
	for i in 7:
		var wrap := CenterContainer.new()
		wrap.custom_minimum_size.x = HabitGrid.DAY_W
		wrap.mouse_filter = Control.MOUSE_FILTER_STOP
		wrap.gui_input.connect(func(e): _on_cell_input(i, e)) # 입력은 wrap이 처리
		var box := Control.new()
		box.custom_minimum_size = CELL_SIZE
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(box)
		cells_box.add_child(wrap)
		_wraps.append(wrap)
		_bases.append(_add_cell_layer(box))
		_fills.append(_add_cell_layer(box))
		_pop_tweens.append(null)
		_fill_tweens.append(null)

func _add_cell_layer(box: Control) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE     # 표시 전용, 입력은 wrap이 받음
	box.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.pivot_offset = CELL_SIZE * 0.5                 # 가운데를 기준으로 커진다
	return p
		
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
			_render_cell(i, true)            # 사용자가 누른 것 — 여기만 연출한다
			changed.emit()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_active[i] = not _active[i]          # 우클릭 = 활성/비활성 토글
		_render_cell(i)
		changed.emit()

func _render_cell(i: int, animate: bool = false) -> void:
	var base := _bases[i]
	var fill := _fills[i]
	base.theme_type_variation = &"VgHabitCellOff" if not _active[i] else &"VgHabitCell"
	fill.theme_type_variation = &"VgHabitCellDone"
	var target := 1.0 if (_active[i] and _checks[i]) else 0.0
	if animate:
		_pop_cell(i, target)
	else:
		fill.modulate.a = target
		_set_cell_scale(1.0, i)
	_wraps[i].tooltip_text = TranslationServer.translate("HABIT_DAY_TOGGLE_OFF" if _active[i] else "HABIT_DAY_TOGGLE_ON")

# 색이 스며드는 동안 칸이 살짝 커졌다 돌아온다 — 작은 표적이라 눌린 반응이 없으면 먹었는지 애매하다.
func _pop_cell(i: int, target: float) -> void:
	_kill_cell_tweens(i)                     # 같은 칸을 연달아 누를 때 이전 것과 겹치지 않게
	_set_cell_scale(1.0, i)
	# 색과 팝을 한 트윈에 묶지 않는다. set_parallel 뒤의 chain은 느린 쪽까지 기다리므로
	# 커진 채로 멈췄다가 뒤늦게 돌아온다.
	var fade := create_tween()
	fade.tween_property(_fills[i], "modulate:a", target, CELL_FILL_SEC)
	_fill_tweens[i] = fade
	var pop := create_tween()
	pop.tween_method(_set_cell_scale.bind(i), 1.0, CELL_POP_SCALE, CELL_POP_SEC * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_method(_set_cell_scale.bind(i), CELL_POP_SCALE, 1.0, CELL_POP_SEC * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pop_tweens[i] = pop

func _kill_cell_tweens(i: int) -> void:
	for t in [_pop_tweens[i], _fill_tweens[i]]:
		if t != null and t.is_valid():
			t.kill()

func _set_cell_scale(s: float, i: int) -> void:
	var v := Vector2.ONE * s
	_bases[i].scale = v
	_fills[i].scale = v
