class_name NoteEditor
extends VBoxContainer

signal back_requested

@onready var back_button: Button = $BackButton
@onready var meta_label: Label = $MetaLabel
@onready var title_label: Label = $TitleLabel
@onready var edit: TextEdit = $Edit
@onready var clear_button: Button = $ClearButton

var _event_id: int = 0

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	clear_button.pressed.connect(_on_clear)
	edit.focus_exited.connect(commit)
	edit.gui_input.connect(_on_edit_gui_input)

func open_for(event_id: int, meta: String, title: String) -> void:
	commit()                                 # 다른 항목으로 옮기기 전 자동 저장
	_event_id = event_id
	meta_label.text = meta
	title_label.text = title
	edit.text = Save.activity_log.note_of(event_id)

func commit() -> void:
	if _event_id == 0:
		return
	Save.activity_log.set_note(_event_id, edit.text)

func _on_back() -> void:
	commit()
	_event_id = 0
	back_requested.emit()

func _on_clear() -> void:
	edit.text = ""
	commit()
	
func _on_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		if event.shift_pressed:
			edit.insert_text_at_caret("\n")
		else:
			edit.release_focus()          # focus_exited → _commit
