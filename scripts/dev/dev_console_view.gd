extends PanelContainer

## 개발자 콘솔의 화면(docs/specs/dev-console.md). 셸 창의 자식으로 붙어 셸 창의 키 입력을 받는다.
## 명령의 뜻은 모른다 — 친 줄을 submitted 로 넘기고, 받은 줄을 출력에 쌓기만 한다.

signal submitted(line: String)

const TOGGLE_KEY := KEY_F12
const LOG_LINES := 8                # 패널 높이 안에 입력 줄까지 들어가는 만큼
const HEIGHT := 240.0
const C_BG := Color(0.12, 0.11, 0.10, 0.92)
const C_TEXT := Color("#E8E2D6")

var _log: Label
var _line: LineEdit
var _lines: Array[String] = []
var _history: Array[String] = []
var _hist_i := 0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -HEIGHT
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	add_child(box)
	_log = Label.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log.clip_text = true
	_log.add_theme_color_override("font_color", C_TEXT)
	_log.add_theme_font_size_override("font_size", 14)
	box.add_child(_log)
	_line = LineEdit.new()
	_line.placeholder_text = "help"
	_line.add_theme_font_size_override("font_size", 15)
	box.add_child(_line)
	_line.text_submitted.connect(_on_submitted)


## 입력 줄에 포커스가 있어도 F12·Esc·화살표가 먹어야 한다. GUI 보다 먼저 받는 _input 에서 본다
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == TOGGLE_KEY:
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	match k.keycode:
		KEY_ESCAPE:
			_toggle()
			get_viewport().set_input_as_handled()
		KEY_UP:
			_recall(-1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_recall(1)
			get_viewport().set_input_as_handled()


## 출력에 한 줄(여러 줄이어도 된다)을 쌓는다
func print_line(text: String) -> void:
	for line in text.split("\n"):
		_lines.append(line)
	while _lines.size() > LOG_LINES:
		_lines.pop_front()
	_log.text = "\n".join(_lines)


func clear_log() -> void:
	_lines.clear()
	_log.text = ""


func _toggle() -> void:
	visible = not visible
	if visible:
		_line.grab_focus()
	else:
		_line.release_focus()


func _on_submitted(line: String) -> void:
	_line.clear()
	line = line.strip_edges()
	if line == "":
		return
	_history.append(line)
	_hist_i = _history.size()
	print_line("> " + line)
	submitted.emit(line)


func _recall(step: int) -> void:
	if _history.is_empty():
		return
	_hist_i = clampi(_hist_i + step, 0, _history.size())
	_line.text = _history[_hist_i] if _hist_i < _history.size() else ""
	_line.caret_column = _line.text.length()
