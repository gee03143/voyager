extends VBoxContainer

const TODO_ROW := preload("res://scenes/todo/TodoRow.tscn")
const DUE_POPUP := preload("res://scenes/todo/DuePopup.tscn")
const GROUP_EDIT_POPUP := preload("res://scenes/todo/GroupEditPopup.tscn")
const SAVE_DEBOUNCE := 0.5

@onready var scroll: ScrollContainer  = $ScrollContainer
@onready var list: ReorderList  = $ScrollContainer/List
@onready var progress: ProgressBar = $ProgressRow/ProgressBar
@onready var progress_label: Label = $ProgressRow/ProgressLabel
@onready var add_button: Button = $AddButton
@onready var group_option: OptionButton = $Header/GroupOption
@onready var sort_key_button: MenuButton = $Header/SortKeyButton
@onready var sort_dir_button: Button = $Header/SortDirButton
@onready var group_edit_button: Button = $Header/GroupEditButton

var _rows: Array[TodoRow] = []
var _save_timer: Timer

var _due_popup: DuePopup
var _editing_row: TodoRow = null

var _group_edit_popup: GroupEditPopup

var _group: TodoGroup

var _sort_key: int = TodoSort.Key.MANUAL
var _sort_desc: bool = false
var _sorter := TodoSort.new()             # _order_idx 대체

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	add_child(_save_timer)
	_save_timer.timeout.connect(func(): Save.save_game())
	add_button.pressed.connect(_on_add_pressed)
	
	_due_popup = DUE_POPUP.instantiate()
	add_child(_due_popup)
	_due_popup.confirmed.connect(_on_due_confirmed)
	_due_popup.popup_hide.connect(func(): _editing_row = null)
	
	_group_edit_popup = GROUP_EDIT_POPUP.instantiate()
	add_child(_group_edit_popup)
	_group_edit_popup.groups_changed.connect(_on_groups_changed)
	group_edit_button.pressed.connect(func(): _group_edit_popup.open())

	var pm := sort_key_button.get_popup()
	pm.id_pressed.connect(_on_sort_key_selected)
	sort_dir_button.pressed.connect(_on_sort_dir_toggled)
	
	group_option.item_selected.connect(_on_group_selected)
	_refresh_group_dropdown()
	_load_group(Save.current_group_index)
	
	list.token = &"todo"
	list.reordered.connect(_on_reordered)

func _add_row(todo: Todo) -> TodoRow:
	var row := TODO_ROW.instantiate() as TodoRow
	list.add_child(row)              # 트리에 먼저 → @onready 준비
	row.set_drag_enabled(_sort_key == TodoSort.Key.MANUAL)
	row.setup(todo)                  # changed 연결 '전'이라 setup 이 저장 안 유발
	row.changed.connect(_on_list_changed)
	row.delete_requested.connect(_on_row_delete)
	row.due_edit_requested.connect(_on_due_edit)
	row.completed.connect(_on_task_completed)
	_rows.append(row)
	return row

func _on_add_pressed() -> void:
	var row := _add_row(Todo.new())  # 빈 할 일 추가
	_on_list_changed()               # 새 항목 저장
	row.start_edit()
	await get_tree().process_frame
	scroll.ensure_control_visible(row)

func _on_row_delete(row: TodoRow) -> void:
	_rows.erase(row)
	row.queue_free()
	_on_list_changed()

func _on_list_changed() -> void:
	_group.tasks.clear()
	for r in _rows:
		_group.tasks.append(r.get_data())
	_update_progress()
	_apply_sort()
	_save_timer.start()
	
func _update_progress() -> void:
	var total := _rows.size()
	var done := 0
	for r in _rows:
		if r.is_done():
			done += 1
	progress.max_value = max(total, 1)
	progress.value = done
	progress_label.text = "%d/%d" % [done, total]
	
func _on_due_edit(row: TodoRow) -> void:
	_editing_row = row
	var d := row.get_data()
	_due_popup.open_for(d.due_date, d.text)   # 현재 마감일·할 일 이름 전달

func _on_task_completed(title: String) -> void:
	Save.activity_log.add("todo", {"title": title})

func _on_due_confirmed(iso: String) -> void:
	if _editing_row:
		_editing_row.set_due(iso)             # set_due 가 changed → 저장

func _on_groups_changed() -> void:
	if Save.todo_groups.find(_group) == -1:          # 활성 그룹이 삭제됨
		_load_group(clampi(Save.current_group_index, 0, Save.todo_groups.size() - 1))
	Save.current_group_index = Save.todo_groups.find(_group)   # 정체성으로 현재 인덱스 갱신
	_refresh_group_dropdown()
	_save_timer.start()
	
func _on_sort_key_selected(id: int) -> void:
	_sort_key = id
	_persist_sort()
	_update_sort_ui()
	_apply_sort()

func _on_sort_dir_toggled() -> void:
	_sort_desc = not _sort_desc
	_persist_sort()
	_update_sort_ui()
	_apply_sort()

func _update_sort_ui() -> void:
	var manual := _sort_key == TodoSort.Key.MANUAL
	sort_key_button.text = "정렬: %s" % TodoSort.NAMES[_sort_key]
	sort_dir_button.text = "🔽" if _sort_desc else "🔼"
	sort_dir_button.visible = not manual       # 수동엔 방향 없음
	for r in _rows:
		r.set_drag_enabled(manual)

func _persist_sort() -> void:
	_group.sort_key = _sort_key
	_group.sort_desc = _sort_desc
	_save_timer.start()

func _apply_sort() -> void:
	var ordered := _sorter.ordered(_rows, _sort_key, _sort_desc)
	for i in ordered.size():
		list.move_child(ordered[i], i)        # 화면(자식 순서)만 재배치
	
func _refresh_group_dropdown() -> void:
	group_option.clear()
	for i in Save.todo_groups.size():
		group_option.add_item(Save.todo_groups[i].name, i)
	group_option.select(Save.current_group_index)

func _on_group_selected(idx: int) -> void:
	_load_group(idx)
	Save.current_group_index = clampi(idx, 0, Save.todo_groups.size() - 1)
	_save_timer.start()                         # 활성 그룹 저장

func _load_group(index: int) -> void:
	index = clampi(index, 0, Save.todo_groups.size() - 1)
	_group = Save.todo_groups[index]
	for r in _rows:                             # 기존 행 즉시 제거(깜빡임 방지)
		list.remove_child(r)
		r.queue_free()
	_rows.clear()
	_sort_key = clampi(_group.sort_key, 0, TodoSort.NAMES.size() - 1)
	_sort_desc = _group.sort_desc
	for todo in _group.tasks:                   # 새 그룹 로드
		_add_row(todo)
	_update_progress()
	_update_sort_ui()
	_apply_sort()
	
func _on_reordered(from: int, to: int) -> void:
	if _sort_key != TodoSort.Key.MANUAL:
		return
	var r := _rows[from]
	_rows.remove_at(from)
	_rows.insert(to, r)
	_on_list_changed()                         # _rows → tasks 재구성 + 저장
