extends HBoxContainer

const HISTORY_ROW := preload("res://scenes/record/journal/MoodHistoryRow.tscn")

@onready var level_row: HBoxContainer = $Left/LevelRow
@onready var memo_edit: TextEdit = $Left/MemoEdit
@onready var record_button: Button = $Left/ButtonRow/RecordButton
@onready var cancel_button: Button = $Left/ButtonRow/CancelEditButton
@onready var history_list: VBoxContainer = $Right/HistoryScroll/HistoryList

var _nav := ButtonGroupNav.new()
var _selected_level: int = 0
var _editing_id: int = 0

func _ready() -> void:
	_nav.setup_from(level_row, false)
	_nav.selected.connect(_on_level_selected)
	memo_edit.gui_input.connect(_on_memo_gui_input)
	record_button.disabled = true
	record_button.pressed.connect(_on_record)
	cancel_button.pressed.connect(_on_cancel_edit)
	cancel_button.visible = false
	visibility_changed.connect(_on_visibility)
	_rebuild_history()

func _on_visibility() -> void:
	if visible:
		_rebuild_history()

func _on_memo_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		if event.shift_pressed:
			memo_edit.insert_text_at_caret("\n")
		else:
			memo_edit.release_focus()

func _on_level_selected(index: int) -> void:
	_selected_level = index + 1
	record_button.disabled = (index < 0)

func _on_record() -> void:
	if _selected_level == 0:
		return
	var memo := memo_edit.text.strip_edges()
	if _editing_id != 0:
		Save.mood.update_entry(_editing_id, _selected_level, memo)
	else:
		var id := Save.mood.add_entry(_selected_level, memo)
		Save.activity_log.add("mood", {"entry_id": id})
	_reset_to_new()
	_rebuild_history()

func _on_cancel_edit() -> void:
	_reset_to_new()

func _reset_to_new() -> void:
	_editing_id = 0
	memo_edit.text = ""
	record_button.text = TranslationServer.translate("MOOD_RECORD_BUTTON")
	cancel_button.visible = false
	_selected_level = 0
	record_button.disabled = true
	for btn in level_row.get_children():
		if btn is Button:
			btn.set_pressed_no_signal(false)

func _on_history_selected(entry: Dictionary) -> void:
	_editing_id = int(entry.get("id", 0))
	var level := clampi(int(entry.get("level", 3)), 1, 5)
	_nav.select(level - 1)
	memo_edit.text = str(entry.get("memo", ""))
	record_button.text = TranslationServer.translate("MOOD_UPDATE_BUTTON")
	cancel_button.visible = true

func _rebuild_history() -> void:
	for c in history_list.get_children():
		c.queue_free()
	var entries := Save.mood.entries.duplicate()
	entries.sort_custom(func(a, b): return int(a.get("ts", 0)) > int(b.get("ts", 0)))
	for e in entries:
		var row := HISTORY_ROW.instantiate()
		history_list.add_child(row)
		row.setup(e)
		row.selected.connect(func(): _on_history_selected(e))
		row.delete_requested.connect(_on_delete)

func _on_delete(id: int) -> void:
	Save.mood.remove_entry(id)
	if id == _editing_id:
		_reset_to_new()
	_rebuild_history()
