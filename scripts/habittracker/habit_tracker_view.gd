extends VBoxContainer

const HABIT_ROW := preload("res://scenes/habittracker/HabitRow.tscn")
const SAVE_DEBOUNCE := 0.5

@onready var prev_button: Button = $WeekNav/PrevButton
@onready var week_label: Label = $WeekNav/WeekLabel
@onready var next_button: Button = $WeekNav/NextButton
@onready var today_button: Button = $WeekNav/TodayButton
@onready var header: HBoxContainer = $Header
@onready var scroll: ScrollContainer = $ScrollContainer
@onready var list: ReorderList = $ScrollContainer/List
@onready var add_button: Button = $AddButton

var _rows: Array[HabitRow] = []
var _save_timer: Timer
var _day_circles: Array[RadialProgress] = []
var _page: int = 0

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	add_child(_save_timer)
	_save_timer.timeout.connect(func(): Save.save_game())
	add_button.pressed.connect(_on_add_pressed)
	prev_button.pressed.connect(func(): _show_page(_page - 1))
	next_button.pressed.connect(func(): _show_page(_page + 1))
	today_button.pressed.connect(func(): _show_page(Save.habit_weeks.size() - 1))

	_ensure_current_week()
	_build_header()
	list.token = &"habit"
	list.reordered.connect(_on_reordered)
	_show_page(Save.habit_weeks.size() - 1)

func _ensure_current_week() -> void:
	var monday := DateUtil.monday_iso()
	if Save.habit_weeks.is_empty() or Save.habit_weeks[-1]["week_start"] != monday:
		Save.habit_weeks.append({"week_start": monday, "checks": {}})
	Save.save_game()

func _build_header() -> void:
	var handle_spacer := Control.new()
	handle_spacer.custom_minimum_size.x = HabitGrid.HANDLE_W   # 핸들 열만큼 비움
	header.add_child(handle_spacer)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = HabitGrid.NAME_W      # 항목명 열만큼 비움
	header.add_child(spacer)
	for d in HabitGrid.DAY_NAMES:
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = HabitGrid.DAY_W
		var lbl := Label.new()
		lbl.text = d
		lbl.custom_minimum_size.x = HabitGrid.DAY_W
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lbl)
		var circle := RadialProgress.new()
		circle.custom_minimum_size = Vector2(HabitGrid.DAY_W, 28)
		col.add_child(circle)
		header.add_child(col)
		_day_circles.append(circle)

func _show_page(page: int) -> void:
	_page = clampi(page, 0, Save.habit_weeks.size() - 1)
	var week: Dictionary = Save.habit_weeks[_page]
	var checks: Dictionary = week.get("checks", {})

	for r in _rows: list.remove_child(r); r.queue_free()
	_rows.clear()
	for def in Save.habit_defs:                       # ← defs가 멤버십·순서
		var did := int(def["id"])
		_add_row(Habit.from_parts(did, def, checks.get(str(did), [])))   # 기록 없으면 빈 체크
	_refresh_progress()

	var is_current := _page == Save.habit_weeks.size() - 1
	var range_text := DateUtil.week_range_label(week["week_start"])
	week_label.text = ("이번 주 (%s)" % range_text) if is_current else range_text
	prev_button.disabled = _page <= 0
	next_button.disabled = is_current

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
	habit.id = Habit._generate_new_id()
	habit.title = "새 습관 %d" % (Save.habit_defs.size() + 1)
	var row := _add_row(habit)
	_on_list_changed()
	row.name_edit.grab_focus()
	await get_tree().process_frame
	scroll.ensure_control_visible(row)

func _on_row_delete(row: HabitRow) -> void:
	_rows.erase(row)
	row.queue_free()
	_on_list_changed()

func _on_list_changed() -> void:
	var defs := []
	var checks := {}
	for r in _rows:
		var h := r.get_data()
		defs.append({"id": h.id, "title": h.title, "active_days": h.active_days.duplicate()})
		if h.checks.has(true):                        # 체크 있는 것만 저장(희소)
			checks[str(h.id)] = h.checks.duplicate()
	Save.habit_defs = defs                            # 멤버십·순서·title·active 전역 갱신
	Save.habit_weeks[_page]["checks"] = checks        # 그 주 체크만
	_refresh_progress()
	_save_timer.start()
	
func _sync_shared_fields() -> void:
	var defs := {}
	for it in Save.habit_weeks[_page]["items"]:
		defs[it["id"]] = {"title": it["title"], "active_days": it["active_days"]}
	for wk in Save.habit_weeks:
		for it in wk["items"]:
			if defs.has(it["id"]):
				it["title"] = defs[it["id"]]["title"]
				it["active_days"] = (defs[it["id"]]["active_days"] as Array).duplicate()

func _on_reordered(from: int, to: int) -> void:
	var r := _rows[from]
	_rows.remove_at(from)
	_rows.insert(to, r)
	for i in _rows.size():
		list.move_child(_rows[i], i)   # 화면 순서도 _rows에 맞춤
	_on_list_changed()                 # _rows → Save.habits 스냅샷 + 저장
	
func _refresh_progress() -> void:
	for d in 7:
		var active := 0
		var done := 0
		for r in _rows:
			if r.is_active(d):
				active += 1
				if r.is_checked(d):
					done += 1
		_day_circles[d].value = (float(done) / active) if active > 0 else 0.0
