extends VBoxContainer

const TODO_ROW := preload("res://scenes/todo/TodoRow.tscn")
const SAVE_DEBOUNCE := 0.5

@onready var list: VBoxContainer = $List
@onready var add_button: Button = $AddButton

var _rows: Array[TodoRow] = []
var _save_timer: Timer

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	add_child(_save_timer)
	_save_timer.timeout.connect(func(): Save.save_game())

	add_button.pressed.connect(_on_add_pressed)

	for todo in Save.todos:          # 저장된 할 일 복원
		_add_row(todo)

func _add_row(todo: Todo) -> TodoRow:
	var row := TODO_ROW.instantiate() as TodoRow
	list.add_child(row)              # 트리에 먼저 → @onready 준비
	row.setup(todo)                  # changed 연결 '전'이라 setup 이 저장 안 유발
	row.changed.connect(_on_list_changed)
	row.delete_requested.connect(_on_row_delete)
	_rows.append(row)
	return row

func _on_add_pressed() -> void:
	var row := _add_row(Todo.new())  # 빈 할 일 추가
	_on_list_changed()               # 새 항목 저장
	row.text_edit.grab_focus()       # 바로 입력 가능하게

func _on_row_delete(row: TodoRow) -> void:
	_rows.erase(row)
	row.queue_free()
	_on_list_changed()

func _on_list_changed() -> void:
	# 행 전체 → Save.todos 스냅샷 (메모리 즉시)
	Save.todos.clear()
	for r in _rows:
		Save.todos.append(r.get_data())
	_save_timer.start()              # 디스크 저장은 디바운스
