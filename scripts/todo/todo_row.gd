class_name TodoRow
extends PanelContainer

signal changed
signal delete_requested(row: TodoRow)
signal due_edit_requested(row: TodoRow)

@onready var done_check: CheckBox = $HBox/DoneCheck
@onready var text_display: RichTextLabel = $HBox/TextDisplay
@onready var text_edit: LineEdit = $HBox/TextEdit
@onready var delete_button: Button = $HBox/DeleteButton
@onready var due_label: Label = $HBox/DueLabel
@onready var due_button: Button = $HBox/DueButton
@onready var drag_handle: DragHandle = $HBox/DragHandle

var _text: String = ""
var _done: bool = false
var _due: String = ""

func _ready() -> void:
	done_check.toggled.connect(_on_done_toggled)
	text_display.gui_input.connect(_on_display_input)
	text_edit.text_submitted.connect(_on_edit_submitted)
	text_edit.focus_exited.connect(_commit_edit)
	delete_button.pressed.connect(func(): delete_requested.emit(self))
	due_button.pressed.connect(func(): due_edit_requested.emit(self))
	_show_display()
	_render()
	
	drag_handle.row = self
	drag_handle.token = &"todo"

# Data -> UI
func setup(todo: Todo) -> void:
	_text = todo.text
	_done = todo.done
	done_check.set_pressed_no_signal(todo.done)
	_due = todo.due_date
	_render()
	_render_due()
	
# UI -> Data
func get_data() -> Todo:
	var t := Todo.new()
	t.done = _done
	t.text = _text
	t.due_date = _due
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
		text_display.text = "(할 일 입력)"
		text_display.modulate.a = 0.5
	elif _done:
		text_display.text = "[s]%s[/s]" % safe
		text_display.modulate.a = 0.5
	else:
		text_display.text = safe
		text_display.modulate.a = 1.0
		
func _render_due() -> void:
	due_label.text = _format_due(_due)
	
func _format_due(iso: String) -> String:
	if iso.is_empty():
		return ""
	var p := iso.split("-")
	if p.size() != 3:
		return iso
	return "%d/%d/%d" % [int(p[0]), int(p[1]), int(p[2])]   # "2026/6/13"
	
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
