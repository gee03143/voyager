extends VBoxContainer

const HABIT_ROW := preload("res://scenes/habittracker/HabitRow.tscn")
const SAVE_DEBOUNCE := 0.5

@onready var header: HBoxContainer = $Header
@onready var scroll: ScrollContainer = $ScrollContainer
@onready var list: ReorderList = $ScrollContainer/List
@onready var add_button: Button = $AddButton

var _rows: Array[HabitRow] = []
var _save_timer: Timer

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	add_child(_save_timer)
	_save_timer.timeout.connect(func(): Save.save_game())
	add_button.pressed.connect(_on_add_pressed)

	_build_header()
	for habit in Save.habits:        # 저장된 습관 복원
		_add_row(habit)
		
	list.token = &"habit"
	list.reordered.connect(_on_reordered)

func _build_header() -> void:
	var handle_spacer := Control.new()
	handle_spacer.custom_minimum_size.x = HabitGrid.HANDLE_W   # 핸들 열만큼 비움
	header.add_child(handle_spacer)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = HabitGrid.NAME_W      # 항목명 열만큼 비움
	header.add_child(spacer)
	for d in HabitGrid.DAY_NAMES:
		var lbl := Label.new()
		lbl.text = d
		lbl.custom_minimum_size.x = HabitGrid.DAY_W
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(lbl)

func _add_row(habit: Habit) -> HabitRow:
	var row := HABIT_ROW.instantiate() as HabitRow
	list.add_child(row)              # 트리에 먼저 → @onready·셀 준비
	row.setup(habit)                 # changed 연결 '전'이라 setup 이 저장 안 유발
	row.changed.connect(_on_list_changed)
	row.delete_requested.connect(_on_row_delete)
	_rows.append(row)
	return row
	
func _on_add_pressed() -> void:
	var habit := Habit.new()
	habit.title = "새 습관 %d" % (_rows.size() + 1)
	var row := _add_row(habit)
	_on_list_changed()
	row.name_edit.grab_focus()
	row.name_edit.select_all()
	await get_tree().process_frame
	scroll.ensure_control_visible(row)

func _on_row_delete(row: HabitRow) -> void:
	_rows.erase(row)
	row.queue_free()
	_on_list_changed()

func _on_list_changed() -> void:
	Save.habits.clear()
	for r in _rows:
		Save.habits.append(r.get_data())
	_save_timer.start()

func _on_reordered(from: int, to: int) -> void:
	var r := _rows[from]
	_rows.remove_at(from)
	_rows.insert(to, r)
	for i in _rows.size():
		list.move_child(_rows[i], i)   # 화면 순서도 _rows에 맞춤
	_on_list_changed()                 # _rows → Save.habits 스냅샷 + 저장
