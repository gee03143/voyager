class_name TodoRow
extends PanelContainer

signal changed
signal completed(title: String)
signal delete_requested(row: TodoRow)
signal due_edit_requested(row: TodoRow)

# 행 하나짜리 작은 변화라 짧다. 줄이 밀리는 동안 손이 먼저 도착하면 오클릭이 나므로
# 이 셋의 합이 커서가 다음 행으로 옮겨가는 시간보다 짧아야 한다.
const ENTER_SEC := 0.12    # 자리가 열리는 시간
const FADE_SEC := 0.08     # 내용이 스며드는 시간. 자리보다 짧아 열린 뒤에 채워진다
const EXIT_SEC := 0.12

@onready var hbox: HBoxContainer = $HBox
@onready var drag_handle: DragHandle = $HBox/DragHandle
@onready var done_check: CheckBox = $HBox/DoneCheck
@onready var text_display: RichTextLabel = $HBox/TextDisplay
@onready var text_edit: LineEdit = $HBox/TextEdit

#RightSlot
@onready var due_label: Label = $HBox/RightSlot/DueLabel
@onready var due_button: Button = $HBox/RightSlot/Actions/DueButton
@onready var delete_button: HoldButton = $HBox/RightSlot/Actions/DeleteButton

var _text: String = ""
var _done: bool = false
var _due: String = ""
var _created_ts: int = 0
var _flow_tween: Tween
var _empty_style := StyleBoxEmpty.new()

func _ready() -> void:
	done_check.toggled.connect(_on_done_toggled)
	text_display.gui_input.connect(_on_display_input)
	text_edit.text_submitted.connect(_on_edit_submitted)
	text_edit.focus_exited.connect(_commit_edit)
	delete_button.held.connect(func(): delete_requested.emit(self))
	due_button.pressed.connect(func(): due_edit_requested.emit(self))
	_show_display()
	_render()
	
	drag_handle.row = self
	drag_handle.token = &"todo"
	
	HoverReveal.setup(self, [due_button, delete_button])
	mouse_entered.connect(func(): due_label.modulate.a = 0.0)
	mouse_exited.connect(func(): due_label.modulate.a = 1.0)
	_set_actions_shown(false)

# Data -> UI
func setup(todo: Todo) -> void:
	_text = todo.text
	_done = todo.done
	done_check.set_pressed_no_signal(todo.done)
	_due = todo.due_date
	_created_ts = todo.created_ts
	_render()
	_render_due()
	
# UI -> Data
func get_data() -> Todo:
	var t := Todo.new()
	t.done = _done
	t.text = _text
	t.due_date = _due
	t.created_ts = _created_ts
	return t
	
func start_edit() -> void:
	text_edit.text = _text
	text_display.hide()
	text_edit.show()
	text_edit.grab_focus()
	text_edit.caret_column = text_edit.text.length()
	
func set_due(iso: String) -> void:
	_due = iso
	_render_due()
	changed.emit()
	
func is_done() -> bool:
	return _done
	
func _on_done_toggled(pressed: bool) -> void:
	_done = pressed
	_render()
	if _done and not _text.strip_edges().is_empty():
		completed.emit(_text)
	changed.emit()

func get_text() -> String:
	return _text

func get_due() -> String:
	return _due

func _on_display_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.double_click \
			and event.button_index == MOUSE_BUTTON_LEFT:
		start_edit()                       # 더블클릭 → 편집
	
func _on_edit_submitted(_t: String) -> void:
	text_edit.release_focus()

func _commit_edit() -> void:
	if not text_edit.visible:
		return
	_text = text_edit.text.strip_edges()
	_show_display()
	_render()
	changed.emit()
	
func _show_display() -> void:
	text_edit.hide()
	text_display.show()
	
func _render() -> void:
	var safe := _text.replace("[", "[lb]")   # 사용자 텍스트의 BBCode 주입 방지
	if _text.is_empty():
		text_display.text = TranslationServer.translate("TODO_EMPTY_PLACEHOLDER")
		text_display.modulate.a = 0.5
	elif _done:
		text_display.text = "[s]%s[/s]" % safe
		text_display.modulate.a = 0.5
	else:
		text_display.text = safe
		text_display.modulate.a = 1.0
		
func _render_due() -> void:
	due_label.text = DateUtil.format_due(_due)
	
func set_drag_enabled(b: bool) -> void:
	drag_handle.enabled = b
	
func make_drag_preview() -> Control:
	var ghost := duplicate() as Control
	ghost.set_script(null)
	ghost.get_node(get_path_to(drag_handle)).queue_free()
	ghost.custom_minimum_size = size               # 레이아웃 밖이라 크기 보존
	var disp := ghost.get_node(get_path_to(text_display)) as RichTextLabel
	disp.text = text_display.text                  # 연출용 라벨 텍스트 명시 복사
	disp.modulate = text_display.modulate          # 취소선/흐림 상태까지
	return ghost
	
func _set_actions_shown(on: bool) -> void:
	due_label.modulate.a = 0.0 if on else 1.0
	for b in [due_button, delete_button]:
		b.modulate.a = 1.0 if on else 0.0
		b.mouse_filter = Control.MOUSE_FILTER_PASS if on else Control.MOUSE_FILTER_IGNORE

# --- 생기고 사라지는 연출 ---
# 컨테이너는 숨긴 자식을 최소 크기 계산에서 뺀다(panel_container.cpp).
# 그래서 내용을 숨기면 행 높이를 자유롭게 줄일 수 있다.
# 스타일박스의 상하 여백도 바닥이 되므로 접는 동안엔 그것도 비운다.

func play_enter(after: Callable = Callable()) -> void:
	_kill_flow()
	var full := get_combined_minimum_size().y
	modulate.a = 0.0
	_collapse_shell()
	custom_minimum_size.y = 0.0
	_flow_tween = create_tween()
	_flow_tween.tween_property(self, "custom_minimum_size:y", full, ENTER_SEC) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flow_tween.tween_callback(_restore_shell)
	if after.is_valid():
		_flow_tween.tween_callback(after)   # 자리가 열린 뒤에야 내용을 만질 수 있다
	_flow_tween.tween_property(self, "modulate:a", 1.0, FADE_SEC)

func play_exit(on_done: Callable) -> void:
	_kill_flow()
	var full := size.y
	_flow_tween = create_tween()
	_flow_tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	_flow_tween.tween_callback(_collapse_shell)
	_flow_tween.tween_property(self, "custom_minimum_size:y", 0.0, EXIT_SEC).from(full) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_flow_tween.tween_callback(on_done)

func _collapse_shell() -> void:
	hbox.visible = false
	add_theme_stylebox_override("panel", _empty_style)

func _restore_shell() -> void:
	remove_theme_stylebox_override("panel")
	hbox.visible = true
	custom_minimum_size.y = 0.0      # 고정해두면 나중에 내용이 늘어도 높이가 안 따라간다

func _kill_flow() -> void:
	if _flow_tween != null and _flow_tween.is_valid():
		_flow_tween.kill()
