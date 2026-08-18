extends HBoxContainer

const SAVE_DEBOUNCE := 0.5
const ITEM_ROW := preload("res://scenes/record/journal/GratitudeItemRow.tscn")
const HISTORY_ROW := preload("res://scenes/record/journal/GratitudeHistoryRow.tscn")

@onready var items_box: VBoxContainer = $Left/ItemsScroll/ItemsBox
@onready var add_item_button: Button = $Left/AddItemButton
@onready var history_list: VBoxContainer = $Right/HistoryScroll/HistoryList

var _save_timer: Timer
var _current_id: int = 0
var _today: String = ""

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	add_child(_save_timer)
	_save_timer.timeout.connect(_on_debounce)
	add_item_button.pressed.connect(_on_add_item)
	visibility_changed.connect(_on_visibility)
	_load_today()
	_rebuild_history()

func _on_visibility() -> void:
	if visible:
		_load_today()
		_rebuild_history()
	else:
		_commit()

func _load_today() -> void:
	_today = DateUtil.today_iso()
	var e := Save.gratitude.entry_for_date(_today)
	_current_id = int(e.get("id", 0))
	_clear_items()
	var items: Array = e.get("items", [])
	if items.is_empty():
		_add_item_row("")
	else:
		for it in items:
			_add_item_row(str(it))

func _clear_items() -> void:
	for c in items_box.get_children():
		c.queue_free()

func _add_item_row(text: String, focus: bool = false) -> void:
	var row := ITEM_ROW.instantiate()
	items_box.add_child(row)
	row.set_text(text)
	row.text_changed.connect(func(_t): _save_timer.start())
	row.delete_requested.connect(func(): _on_item_deleted(row))
	if focus:
		row.grab_edit_focus()

func _on_item_deleted(row: Node) -> void:
	row.queue_free()
	if items_box.get_child_count() <= 1:
		_add_item_row("")
	_save_timer.start()

func _on_add_item() -> void:
	_add_item_row("", true)
	_save_timer.start()

func _current_items() -> Array:
	var out := []
	for row in items_box.get_children():
		out.append(row.get_text())
	return out

func _on_debounce() -> void:
	_commit()
	_rebuild_history()

func _commit() -> void:
	var items := _current_items()
	var has_content := false
	for it in items:
		if str(it).strip_edges() != "":
			has_content = true
			break
	if _current_id == 0:
		if not has_content:
			return
		_current_id = Save.gratitude.add_entry(_today)
	Save.gratitude.update_entry(_current_id, items)
	if has_content and not _has_gratitude_event(_current_id):
		Save.activity_log.add("gratitude", {"entry_id": _current_id})

func _has_gratitude_event(entry_id: int) -> bool:
	for e in Save.activity_log.events:
		if str(e.get("type", "")) == "gratitude" and int(e.get("entry_id", 0)) == entry_id:
			return true
	return false

func _rebuild_history() -> void:
	for c in history_list.get_children():
		c.queue_free()
	var past := []
	for e in Save.gratitude.entries:
		if str(e.get("date_iso", "")) != _today:
			past.append(e)
	past.sort_custom(func(a, b): return str(a.get("date_iso", "")) > str(b.get("date_iso", "")))
	for e in past:
		var row := HISTORY_ROW.instantiate()
		history_list.add_child(row)
		row.setup(e)
		row.delete_requested.connect(_on_delete_past)

func _on_delete_past(id: int) -> void:
	Save.gratitude.remove_entry(id)
	_rebuild_history()
