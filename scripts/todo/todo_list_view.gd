extends HBoxContainer

const TODO_ROW := preload("res://scenes/todo/TodoRow.tscn")
const DUE_POPUP := preload("res://scenes/todo/DuePopup.tscn")
const GROUP_EDIT_POPUP := preload("res://scenes/todo/GroupEditPopup.tscn")
const SAVE_DEBOUNCE := 0.5
# 체크된 모습을 보여주는 시간.
# 길면 커서가 다음 행으로 옮겨간 뒤에 줄이 밀려 오클릭이 난다 — 손보다 먼저 끝나야 한다.
const DONE_HOLD_SEC := 0.18

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
var _rows_by_todo: Dictionary = {}   # Todo → TodoRow. 매번 새로 만들지 않고 재사용한다
var _done_header: Button
var _exiting: Dictionary = {}        # 접히는 중인 Todo → 그 할 일이 속한 TodoGroup
var _hold_timer: Timer
var _pending_move: Todo = null       # 체크된 채 제자리에 머무는 중인 할 일
var _pending_move_was_done := false  # 그 할 일이 머물기 전에 있던 자리
var _moving_todo: Todo = null        # 자리를 옮기는 중 — 새 자리에서 펼쳐질 대상
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

	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = DONE_HOLD_SEC
	add_child(_hold_timer)
	_hold_timer.timeout.connect(_flush_move)

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
	_hover_indicator.color = Color(0.16470589, 0.14901961, 0.12156863, 0.12)
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

# 행을 파괴하지 않고 재사용한다. 파괴되면 움직일 대상이 남지 않아 연출을 걸 수 없다.
# 사용자 눈에는 아무 변화가 없어야 한다 — 같은 화면, 같은 정렬, 같은 동작.
func _rebuild_task_list(entries: Array) -> void:
	var pending: Array = []
	var done: Array = []
	for e in entries:
		var is_done: bool = e["todo"].done
		if e["todo"] == _pending_move:
			is_done = _pending_move_was_done   # 머무는 동안에는 이전 자리를 지킨다
		if is_done:
			done.append(e)
		else:
			pending.append(e)

	_update_progress(pending.size(), done.size())

	# 이번에 행이 있어야 하는 할 일과 그 자리. 목록에 없거나 접힌 완료 구간의 행은 버린다.
	var wanted := {}
	for e in pending:
		wanted[e["todo"]] = pending_list
	if not _done_collapsed:
		for e in done:
			wanted[e["todo"]] = task_list
	for todo in _rows_by_todo.keys():
		if not wanted.has(todo):
			_drop_row(todo)

	var pending_rows: Array = []
	for e in pending:
		pending_rows.append(_sync_row(pending_list, e["todo"], e["group"]))

	if _current_spec["mode"] == "group":
		var group: TodoGroup = _current_spec["group"]
		pending_rows = _sorter.ordered(pending_rows, group.sort_key, group.sort_desc)
	for i in pending_rows.size():
		pending_list.move_child(pending_rows[i], i)

	_pending_todos = []
	for r in pending_rows:
		_pending_todos.append(_row_todo_map[r])

	_drop_done_header()
	if not done.is_empty():
		_add_done_header(done.size())
		if not _done_collapsed:
			for e in done:
				_sync_row(task_list, e["todo"], e["group"])
	_order_task_list(done)
	_moving_todo = null                      # 완료 구간이 접혀 있어 행이 버려졌을 수도 있다

# 재사용하므로 자리는 매번 다시 잡아준다. 순서: 미완료 목록 → 완료 헤더 → 완료 행
func _order_task_list(done: Array) -> void:
	task_list.move_child(pending_list, 0)
	var at := 1
	if _done_header != null:
		task_list.move_child(_done_header, at)
		at += 1
	if _done_collapsed:
		return
	for e in done:
		var row: TodoRow = _rows_by_todo.get(e["todo"])
		if row != null:
			task_list.move_child(row, at)
			at += 1

func _drop_done_header() -> void:
	if _done_header == null or not is_instance_valid(_done_header):
		_done_header = null
		return
	task_list.remove_child(_done_header)   # 자리 계산이 어긋나지 않게 즉시 빼낸다
	_done_header.queue_free()
	_done_header = null

func _drop_row(todo) -> void:
	# 접히는 중이던 행이 먼저 파괴되면 트윈도 같이 죽어 삭제가 미완으로 남는다.
	# 여기서 모델을 마저 정리한다(이미 목록 밖이라 다시 그릴 필요는 없다).
	if _exiting.has(todo):
		var g: TodoGroup = _exiting[todo]
		_exiting.erase(todo)
		g.tasks.erase(todo)
		_save_timer.start()
	var row: TodoRow = _rows_by_todo.get(todo)
	if row == null:
		return
	_rows_by_todo.erase(todo)
	_row_todo_map.erase(row)
	var p := row.get_parent()
	if p != null:
		p.remove_child(row)
	row.queue_free()

func _update_progress(pending_count: int, done_count: int) -> void:
	var total := pending_count + done_count
	progress_bar.max_value = max(total, 1)
	progress_bar.value = done_count
	progress_label.text = "%d/%d" % [done_count, total]

func _sync_row(parent: Node, todo: Todo, group: TodoGroup) -> TodoRow:
	var row: TodoRow = _rows_by_todo.get(todo)
	if row == null:
		row = TODO_ROW.instantiate() as TodoRow
		parent.add_child(row)                # 트리에 먼저 → @onready 준비
		_rows_by_todo[todo] = row
	elif row.get_parent() != parent:
		row.reparent(parent, false)          # 완료 여부가 바뀌어 자리가 달라졌다
	_bind_row(row, todo, group)
	row.set_drag_enabled(_current_spec["mode"] == "group")
	row.setup(todo)
	_row_todo_map[row] = todo
	# 방금 추가한 할 일에만 연출을 건다. 그룹을 바꿀 때도 행은 새로 생기지만 그건 추가가 아니다.
	if todo == _pending_focus_todo:
		_pending_focus_todo = null
		if is_visible_in_tree():
			row.play_enter(row.start_edit)
		else:
			row.start_edit()
	elif todo == _moving_todo:
		_moving_todo = null
		row.play_enter()                     # 접힌 채로 옮겨왔으니 새 자리에서 다시 펼친다
	return row

# 스마트 목록에서는 같은 할 일이 다른 그룹으로 옮겨갈 수 있어 바인딩을 매번 다시 건다.
func _bind_row(row: TodoRow, todo: Todo, group: TodoGroup) -> void:
	for sig in [row.changed, row.delete_requested, row.due_edit_requested]:
		for c in sig.get_connections():
			sig.disconnect(c["callable"])
	row.changed.connect(_on_row_changed.bind(row, todo, group))
	row.delete_requested.connect(_on_row_delete.bind(todo, group))
	row.due_edit_requested.connect(_on_row_due_edit.bind(todo))

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
	# 완료 여부가 바뀌면 행이 다른 자리로 옮겨간다. 체크된 모습을 잠깐 보여준 뒤에 옮긴다 —
	# 누른 것이 그 자리에서 곧바로 사라지면 그냥 없어진 것으로 읽힌다.
	if todo.done != was_done and is_visible_in_tree():
		_hold_move(todo, was_done)
		return
	_rebuild_rail()

# 머무는 중에 다른 할 일을 건드리면 앞의 것은 기다리기를 그만두고 곧바로 옮겨간다.
func _hold_move(todo: Todo, was_done: bool) -> void:
	if _pending_move != null and _pending_move != todo:
		_hold_timer.stop()
		_move_now()
	elif _pending_move == todo:
		was_done = _pending_move_was_done   # 같은 행을 다시 눌렀다 — 원래 자리는 그대로
	_pending_move = todo
	_pending_move_was_done = was_done
	_hold_timer.start()
	_rebuild_rail()                        # 머무는 자리는 위 분류가 지켜준다

func _flush_move() -> void:
	var todo := _pending_move
	if todo == null:
		return
	var row: TodoRow = _rows_by_todo.get(todo)
	if row == null or not is_instance_valid(row):
		_move_now()
		return
	row.play_exit(_move_now)                       # 제자리에서 접힌 뒤에 옮긴다

func _move_now() -> void:
	if _pending_move == null:
		return
	_moving_todo = _pending_move                   # 새 자리에서 펼쳐질 대상
	_pending_move = null
	_rebuild_rail()
	
# 모델을 먼저 지우면 행이 그 자리에서 사라져 접힐 대상이 없다. 연출이 끝난 뒤에 지운다.
# 그동안 할 일은 아직 모델에 남아 있으므로, 연출이 끝까지 못 가도 삭제는 반드시 완결시킨다.
func _on_row_delete(row: TodoRow, todo: Todo, group: TodoGroup) -> void:
	if row == null or not is_instance_valid(row) or not is_visible_in_tree():
		_erase_todo(todo, group)
		return
	_exiting[todo] = group
	row.play_exit(_erase_todo.bind(todo, group))

func _erase_todo(todo: Todo, group: TodoGroup) -> void:
	if not _exiting.has(todo):
		return                                     # 행이 먼저 사라지며 이미 지워졌다
	_exiting.erase(todo)
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
	_done_header = btn

func _on_add_pressed() -> void:
	if _current_spec["mode"] != "group":
		return
	var todo := Todo.new()
	_current_spec["group"].tasks.append(todo)
	_pending_focus_todo = todo
	_save_timer.start()
	_rebuild_rail()
