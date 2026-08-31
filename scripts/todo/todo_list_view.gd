extends HBoxContainer

const TODO_ROW := preload("res://scenes/todo/TodoRow.tscn")
const DUE_POPUP := preload("res://scenes/todo/DuePopup.tscn")
const GROUP_EDIT_POPUP := preload("res://scenes/todo/GroupEditPopup.tscn")
const SAVE_DEBOUNCE := 0.5

@onready var rail: VBoxContainer = $RailScroll/Rail
@onready var header_label: Label = $ContentPane/HeaderRow/HeaderLabel
@onready var sort_key_button: MenuButton = $ContentPane/HeaderRow/SortKeyButton
@onready var sort_dir_button: Button = $ContentPane/HeaderRow/SortDirButton
@onready var add_button: Button = $ContentPane/AddButton
@onready var task_list: VBoxContainer = $ContentPane/Scroll/TaskList
@onready var pending_list: ReorderList = $ContentPane/Scroll/TaskList/PendingList
@onready var progress_bar: ProgressBar = $ContentPane/ProgressRow/ProgressBar
@onready var progress_label: Label = $ContentPane/ProgressRow/ProgressLabel

var _nav := ButtonGroupNav.new()
var _sorter := TodoSort.new()
var _rail_specs: Array = []
var _current_spec: Dictionary = {}
var _done_collapsed: bool = false
var _pending_focus_todo: Todo = null
var _pending_todos: Array = []
var _row_todo_map: Dictionary = {}
var _hover_indicator: ColorRect

var _save_timer: Timer
var _due_popup: DuePopup
var _group_edit_popup: GroupEditPopup
var _editing_todo: Todo = null

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	add_child(_save_timer)
	_save_timer.timeout.connect(func(): Save.save_todo())

	_due_popup = DUE_POPUP.instantiate()
	add_child(_due_popup)
	_due_popup.confirmed.connect(_on_due_confirmed)

	_group_edit_popup = GROUP_EDIT_POPUP.instantiate()
	add_child(_group_edit_popup)
	_group_edit_popup.groups_changed.connect(func(): _rebuild_rail())

	add_button.pressed.connect(_on_add_pressed)

	pending_list.token = &"todo"
	pending_list.reordered.connect(_on_reordered)

	var pm := sort_key_button.get_popup()
	for i in TodoSort.NAMES.size():
		pm.add_item(tr(TodoSort.NAMES[i]), i)
	pm.id_pressed.connect(_on_sort_key_selected)
	sort_dir_button.pressed.connect(_on_sort_dir_toggled)

	_hover_indicator = ColorRect.new()
	_hover_indicator.color = Color(0.3, 0.5, 0.9, 0.4)
	_hover_indicator.top_level = true
	_hover_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_indicator.visible = false
	add_child(_hover_indicator)

	var idx := Save.current_group_index
	if idx >= 0 and idx < Save.todo_groups.size():
		_current_spec = {"mode": "group", "group": Save.todo_groups[idx]}

	_rebuild_rail()

func _process(_delta: float) -> void:
	if not get_viewport().gui_is_dragging():
		return
	var mouse := get_global_mouse_position()
	if not Rect2(pending_list.global_position, pending_list.size).has_point(mouse):
		pending_list.hide_indicator()
	if _hover_indicator.visible and not Rect2(_hover_indicator.global_position, _hover_indicator.size).has_point(mouse):
		_hover_indicator.visible = false

func _rebuild_rail() -> void:
	for c in rail.get_children():
		c.queue_free()
	var new_specs: Array = []
	var buttons: Array = []

	buttons.append(_add_rail_button(tr("TODO_SMART_TODAY"), _count_due_within(0)))
	new_specs.append({"mode": "smart", "days": 0, "label": tr("TODO_SMART_TODAY")})

	buttons.append(_add_rail_button(tr("TODO_SMART_NEXT7"), _count_due_within(7)))
	new_specs.append({"mode": "smart", "days": 7, "label": tr("TODO_SMART_NEXT7")})

	var lists_row := HBoxContainer.new()
	var lists_label := Label.new()
	lists_label.text = tr("TODO_LISTS_SECTION")
	lists_label.modulate.a = 0.7
	lists_label.size_flags_horizontal = SIZE_EXPAND_FILL
	lists_row.add_child(lists_label)
	var manage_button := Button.new()
	manage_button.text = "✏️"
	manage_button.pressed.connect(func(): _group_edit_popup.open())
	lists_row.add_child(manage_button)
	rail.add_child(lists_row)

	for i in Save.todo_groups.size():
		var g := Save.todo_groups[i]
		buttons.append(_add_rail_button(g.display_name(), g.tasks.size(), g))
		new_specs.append({"mode": "group", "group": g})

	_rail_specs = new_specs
	_nav = ButtonGroupNav.new()
	_nav.setup(buttons, false)
	_nav.selected.connect(_on_rail_selected)
	_nav.select(_find_current_index())

func _find_current_index() -> int:
	if not _current_spec.is_empty():
		for i in _rail_specs.size():
			if _same_spec(_rail_specs[i], _current_spec):
				return i
	return 0

func _same_spec(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or a["mode"] != b["mode"]:
		return false
	if a["mode"] == "group":
		return a["group"] == b["group"]
	return a["days"] == b["days"]

func _add_rail_button(label_text: String, count: int, group: TodoGroup = null) -> Button:
	var b := Button.new()
	b.text = "%s (%d)" % [label_text, count]
	rail.add_child(b)
	if group != null:
		b.set_drag_forwarding(Callable(), _rail_can_drop.bind(b, group), _rail_drop.bind(group))
	return b

func _rail_can_drop(_pos: Vector2, data: Variant, button: Button, _group: TodoGroup) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("token", &"") != &"todo":
		return false
	pending_list.hide_indicator()
	_hover_indicator.global_position = button.global_position
	_hover_indicator.size = button.size
	_hover_indicator.visible = true
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hover_indicator.visible = false

func _rail_drop(_pos: Vector2, data: Variant, group: TodoGroup) -> void:
	var row: TodoRow = data.get("row")
	var todo: Todo = _row_todo_map.get(row)
	if todo == null:
		return
	for g in Save.todo_groups:
		if g.tasks.has(todo):
			if g == group:
				return
			g.tasks.erase(todo)
			break
	group.tasks.append(todo)
	_save_timer.start()
	_rebuild_rail()

func _count_due_within(days: int) -> int:
	var n := 0
	for g in Save.todo_groups:
		for t in g.tasks:
			if not t.done and not t.due_date.is_empty() and DateUtil.days_until(t.due_date) <= days:
				n += 1
	return n

func _on_rail_selected(index: int) -> void:
	var spec: Dictionary = _rail_specs[index]
	if not _same_spec(spec, _current_spec):
		_done_collapsed = false
	_current_spec = spec
	if spec["mode"] == "group":
		var idx := Save.todo_groups.find(spec["group"])
		if idx != -1 and idx != Save.current_group_index:
			Save.current_group_index = idx
			_save_timer.start()
	_show_spec()

func _show_spec() -> void:
	var is_group: bool = _current_spec["mode"] == "group"
	header_label.text = _current_spec["group"].display_name() if is_group else _current_spec["label"]
	add_button.visible = is_group
	_update_sort_ui()
	_rebuild_task_list(_tasks_for(_current_spec))

func _update_sort_ui() -> void:
	var is_group: bool = _current_spec["mode"] == "group"
	sort_key_button.visible = is_group
	sort_dir_button.visible = false
	if not is_group:
		pending_list.token = &""
		return
	var group: TodoGroup = _current_spec["group"]
	var manual: bool = group.sort_key == TodoSort.Key.MANUAL
	sort_key_button.text = tr("TODO_SORT_LABEL").format({"name": tr(TodoSort.NAMES[group.sort_key])})
	sort_dir_button.text = "🔽" if group.sort_desc else "🔼"
	sort_dir_button.visible = not manual
	pending_list.token = &"todo" if manual else &""

func _on_sort_key_selected(id: int) -> void:
	if _current_spec["mode"] != "group":
		return
	_current_spec["group"].sort_key = id
	_save_timer.start()
	_show_spec()

func _on_sort_dir_toggled() -> void:
	if _current_spec["mode"] != "group":
		return
	var group: TodoGroup = _current_spec["group"]
	group.sort_desc = not group.sort_desc
	_save_timer.start()
	_show_spec()

func _tasks_for(spec: Dictionary) -> Array:
	var out: Array = []
	if spec["mode"] == "group":
		var g: TodoGroup = spec["group"]
		for t in g.tasks:
			out.append({"todo": t, "group": g})
		return out
	var days: int = spec["days"]
	for g in Save.todo_groups:
		for t in g.tasks:
			if not t.due_date.is_empty() and DateUtil.days_until(t.due_date) <= days:
				out.append({"todo": t, "group": g})
	return out

func _rebuild_task_list(entries: Array) -> void:
	_row_todo_map.clear()
	pending_list.clear_items()
	for c in task_list.get_children():
		if c != pending_list:
			c.queue_free()

	var pending: Array = []
	var done: Array = []
	for e in entries:
		if e["todo"].done:
			done.append(e)
		else:
			pending.append(e)

	_update_progress(pending.size(), done.size())

	var pending_rows: Array = []
	for e in pending:
		pending_rows.append(_add_task_row(pending_list, e["todo"], e["group"]))

	if _current_spec["mode"] == "group":
		var group: TodoGroup = _current_spec["group"]
		pending_rows = _sorter.ordered(pending_rows, group.sort_key, group.sort_desc)
		for i in pending_rows.size():
			pending_list.move_child(pending_rows[i], i)

	_pending_todos = []
	for r in pending_rows:
		_pending_todos.append(_row_todo_map[r])

	if not done.is_empty():
		_add_done_header(done.size())
		if not _done_collapsed:
			for e in done:
				_add_task_row(task_list, e["todo"], e["group"])

func _update_progress(pending_count: int, done_count: int) -> void:
	var total := pending_count + done_count
	progress_bar.max_value = max(total, 1)
	progress_bar.value = done_count
	progress_label.text = "%d/%d" % [done_count, total]

func _add_task_row(parent: Node, todo: Todo, group: TodoGroup) -> TodoRow:
	var row := TODO_ROW.instantiate() as TodoRow
	parent.add_child(row)
	row.set_drag_enabled(_current_spec["mode"] == "group")
	row.setup(todo)
	_row_todo_map[row] = todo
	row.changed.connect(_on_row_changed.bind(row, todo, group))
	row.delete_requested.connect(_on_row_delete.bind(todo, group))
	row.due_edit_requested.connect(_on_row_due_edit.bind(todo))
	if todo == _pending_focus_todo:
		_pending_focus_todo = null
		row.start_edit()
	return row

func _on_reordered(from: int, to: int) -> void:
	if _current_spec["mode"] != "group":
		return
	var todo: Todo = _pending_todos[from]
	_pending_todos.remove_at(from)
	_pending_todos.insert(to, todo)

	var group: TodoGroup = _current_spec["group"]
	var new_tasks: Array[Todo] = []
	var pending_i := 0
	for t in group.tasks:
		if t.done:
			new_tasks.append(t)
		else:
			new_tasks.append(_pending_todos[pending_i])
			pending_i += 1
	group.tasks = new_tasks
	_save_timer.start()
	_rebuild_rail()

func _on_row_changed(row: TodoRow, todo: Todo, group: TodoGroup) -> void:
	var was_done := todo.done
	todo.text = row.get_text()
	todo.done = row.is_done()
	todo.due_date = row.get_due()
	if todo.done and not was_done and not todo.text.strip_edges().is_empty():
		var id := Save.activity_log.add("todo", {"title": todo.text})
		Companion.notify_todo_completed(id, todo, group)   # 모델이 갱신된 뒤라 잔여 계산이 맞음
	_save_timer.start()
	_rebuild_rail()
	
func _on_row_delete(_row: TodoRow, todo: Todo, group: TodoGroup) -> void:
	group.tasks.erase(todo)
	_save_timer.start()
	_rebuild_rail()

func _on_row_due_edit(row: TodoRow, todo: Todo) -> void:
	_editing_todo = todo
	_due_popup.open_for(todo.due_date, row.get_text())

func _on_due_confirmed(iso: String) -> void:
	if _editing_todo != null:
		_editing_todo.due_date = iso
		_save_timer.start()
		_rebuild_rail()
		_editing_todo = null

func _add_done_header(count: int) -> void:
	var btn := Button.new()
	btn.text = "%s (%d) %s" % [tr("TODO_DONE_SECTION"), count, ("▸" if _done_collapsed else "▾")]
	btn.pressed.connect(func():
		_done_collapsed = not _done_collapsed
		_show_spec()
	)
	task_list.add_child(btn)

func _on_add_pressed() -> void:
	if _current_spec["mode"] != "group":
		return
	var todo := Todo.new()
	_current_spec["group"].tasks.append(todo)
	_pending_focus_todo = todo
	_save_timer.start()
	_rebuild_rail()
