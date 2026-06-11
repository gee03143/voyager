extends VBoxContainer

enum SortKey { MANUAL, DUE, NAME, DONE }
const SORT_NAMES := ["수동", "마감일", "이름", "완료상태"]

const TODO_ROW := preload("res://scenes/todo/TodoRow.tscn")
const DUE_POPUP := preload("res://scenes/todo/DuePopup.tscn")
const SAVE_DEBOUNCE := 0.5

@onready var list: VBoxContainer = $List
@onready var progress: ProgressBar = $ProgressRow/ProgressBar
@onready var progress_label: Label = $ProgressRow/ProgressLabel
@onready var add_button: Button = $AddButton
@onready var sort_key_button: MenuButton = $Header/SortKeyButton
@onready var sort_dir_button: Button = $Header/SortDirButton

var _rows: Array[TodoRow] = []
var _save_timer: Timer

var _due_popup: DuePopup
var _editing_row: TodoRow = null

var _sort_key: int = SortKey.MANUAL
var _sort_desc: bool = false
var _order_idx := {}     #tiebreak

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

	var pm := sort_key_button.get_popup()
	pm.id_pressed.connect(_on_sort_key_selected)
	sort_dir_button.pressed.connect(_on_sort_dir_toggled)

	_sort_key = clampi(Save.todos_sort_key, 0, SORT_NAMES.size() - 1)
	_sort_desc = Save.todos_sort_desc

	for todo in Save.todos:          # 저장된 할 일 복원
		_add_row(todo)
	_update_progress()
	_update_sort_ui()
	_apply_sort()

func _add_row(todo: Todo) -> TodoRow:
	var row := TODO_ROW.instantiate() as TodoRow
	list.add_child(row)              # 트리에 먼저 → @onready 준비
	row.setup(todo)                  # changed 연결 '전'이라 setup 이 저장 안 유발
	row.changed.connect(_on_list_changed)
	row.delete_requested.connect(_on_row_delete)
	row.due_edit_requested.connect(_on_due_edit)
	_rows.append(row)
	return row

func _on_add_pressed() -> void:
	var row := _add_row(Todo.new())  # 빈 할 일 추가
	_on_list_changed()               # 새 항목 저장
	row.start_edit()

func _on_row_delete(row: TodoRow) -> void:
	_rows.erase(row)
	row.queue_free()
	_on_list_changed()

func _on_list_changed() -> void:
	# 행 전체 → Save.todos 스냅샷 (메모리 즉시)
	Save.todos.clear()
	for r in _rows:
		Save.todos.append(r.get_data())
	_update_progress()
	_apply_sort()
	_save_timer.start()              # 디스크 저장은 디바운스
	
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

func _on_due_confirmed(iso: String) -> void:
	if _editing_row:
		_editing_row.set_due(iso)             # set_due 가 changed → 저장
		
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
	sort_key_button.text = "정렬: %s" % SORT_NAMES[_sort_key]
	sort_dir_button.text = "🔽" if _sort_desc else "🔼"

func _persist_sort() -> void:
	Save.todos_sort_key = _sort_key
	Save.todos_sort_desc = _sort_desc
	_save_timer.start()

func _apply_sort() -> void:
	_order_idx.clear()
	for i in _rows.size():
		_order_idx[_rows[i]] = i           # 수동 순서 = 동순위 기준
	var ordered := _rows.duplicate()
	match _sort_key:
		SortKey.DUE:  ordered.sort_custom(_cmp_due)
		SortKey.NAME: ordered.sort_custom(_cmp_name)
		SortKey.DONE: ordered.sort_custom(_cmp_done)
		_:                                   # 수동: _rows 순서
			if _sort_desc: ordered.reverse()
	for i in ordered.size():
		list.move_child(ordered[i], i)       # 화면(자식 순서)만 재배치, _rows 불변

func _cmp_due(a: TodoRow, b: TodoRow) -> bool:
	var da := a.get_due()
	var db := b.get_due()
	if da.is_empty() or db.is_empty():
		if da.is_empty() == db.is_empty():
			return _order_idx[a] < _order_idx[b]   # 둘 다 없음 → 수동 순서
		return db.is_empty()                        # 없는 건 항상 뒤
	if da == db: return false
	return (da < db) != _sort_desc

func _cmp_name(a: TodoRow, b: TodoRow) -> bool:
	var na := a.get_text().to_lower()
	var nb := b.get_text().to_lower()
	if na == nb: return false
	return (na < nb) != _sort_desc

func _cmp_done(a: TodoRow, b: TodoRow) -> bool:
	if a.is_done() == b.is_done(): return false
	return (not a.is_done()) != _sort_desc          # 오름차순=미완료 먼저
