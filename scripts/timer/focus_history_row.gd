class_name FocusHistoryRow
extends PanelContainer

signal note_committed(event_id: int, text: String)

@onready var span_label: Label = $HBox/TimeCol/SpanLabel
@onready var label_label: Label = $HBox/TimeCol/LabelLabel
@onready var note_label: Label = $HBox/NoteCol/NoteLabel
@onready var edit: TextEdit = $HBox/NoteCol/Edit

var _id: int = 0

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	edit.focus_exited.connect(_commit)
	edit.gui_input.connect(_on_edit_gui_input)

func setup(d: Dictionary) -> void:
	_id = int(d["id"])
	span_label.text = str(d["span"])
	label_label.text = str(d["label"])
	edit.text = str(d["note"])
	_render_note()
	var base := get_theme_stylebox("panel")
	var sb: StyleBoxFlat = base.duplicate() if base is StyleBoxFlat else StyleBoxFlat.new()
	sb.border_color = d["accent"]            # 씬 리소스를 복제해 색만 덮음
	add_theme_stylebox_override("panel", sb)

func open_edit() -> void:
	note_label.hide()
	edit.show()
	edit.grab_focus()
	var last := edit.get_line_count() - 1     # 여러 줄 노트 — 마지막 줄 끝으로
	edit.set_caret_line(last)
	edit.set_caret_column(edit.get_line(last).length())

func is_editing() -> bool:
	return edit.visible

func _commit() -> void:
	if not edit.visible:
		return
	edit.hide()
	note_label.show()
	_render_note()
	note_committed.emit(_id, edit.text)

func _render_note() -> void:
	var t := edit.text.strip_edges()
	if t == "":
		note_label.text = TranslationServer.translate("TIMER_HISTORY_ADD_NOTE")
		note_label.modulate.a = 0.5
	else:
		note_label.text = t
		note_label.modulate.a = 1.0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and not edit.visible:
		open_edit()
		accept_event()
		
func _on_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		if event.shift_pressed:
			edit.insert_text_at_caret("\n")
		else:
			edit.release_focus()          # focus_exited → _commit
