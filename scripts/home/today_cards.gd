extends VBoxContainer

## 홈의 "오늘 한눈에" 카드 셋 — 할 일·습관·집중(docs/specs/home.md).
## 읽기 전용이다. 카드를 누르면 그 도구로 넘어간다. 완료 처리는 각 도구의 뷰가 갖고 여기서는 하지 않는다.
## 비율(몇 개 중 몇 개)은 보이지 않는다. 완료율 점수화 금지(README "하지 않는 것").

signal navigate_requested(target: StringName)   # 값은 MainShell.NAV_TARGETS 의 키다

const LIST_MAX := 5                    # 칸마다 이만큼 보이고 나머지는 "+N개"
const SESSION_TYPES := ["pomodoro_session", "timer"]
const C_DONE := Color(1, 1, 1, 0.55)   # 끝낸 줄은 흐리게. 지운 줄은 긋지 않는다

var _todo_box: VBoxContainer
var _habit_box: VBoxContainer
var _focus_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	_todo_box = _card(row, "HOME_TODO_TITLE", &"todo")
	_habit_box = _card(row, "HOME_HABIT_TITLE", &"habit")
	var focus_box := _card(self, "HOME_FOCUS_TITLE", &"timer")
	_focus_label = Label.new()
	focus_box.add_child(_focus_label)


func refresh() -> void:
	_refresh_todo()
	_refresh_habit()
	_refresh_focus()


# ── 할 일: 오늘까지 남은 것 + 오늘 끝낸 것 ──

## 남은 것의 기준은 할 일 도구의 "오늘" 목록과 같다 — 미완료이고 마감이 오늘이거나 지났다(todo_list_view.gd 의 _count_due_within(0)).
## 끝낸 것은 활동 로그의 오늘 할 일 완료다. 마감일 없는 할 일은 보이지 않는다
func _refresh_todo() -> void:
	_clear(_todo_box)
	var due: Array[Todo] = []
	for g in Save.todo_groups:
		for t in g.tasks:
			if not t.done and not t.due_date.is_empty() and DateUtil.days_until(t.due_date) <= 0:
				due.append(t)
	due.sort_custom(func(a: Todo, b: Todo) -> bool: return a.due_date < b.due_date)
	var done: Array[String] = []
	for e in Save.activity_entries_for(DateUtil.today_iso()):
		if str(e.get("type", "")) == "todo":
			done.append(str(e.get("title", "")))
	if due.is_empty() and done.is_empty():
		_line(_todo_box, tr("HOME_TODO_EMPTY"), true)
		return
	if not due.is_empty():
		_sub(_todo_box, "HOME_TODO_DUE")
		var titles: Array[String] = []
		for t in due:
			titles.append(t.text)
		_list(_todo_box, titles, false)
	if not done.is_empty():
		_sub(_todo_box, "HOME_TODO_DONE")
		_list(_todo_box, done, true)


# ── 습관: 오늘 해야 하는 습관과 체크 여부 ──

## 오늘이 활성 요일인 습관만. 기준은 Companion.habit_today 와 같다
func _refresh_habit() -> void:
	_clear(_habit_box)
	var col := (int(DateUtil.today_dict().weekday) + 6) % 7   # 일0..토6 → 월요일 시작
	var checks := {}
	for wk in Save.habit_weeks:
		if str(wk.get("week_start", "")) == DateUtil.monday_iso():
			var c = wk.get("checks", {})
			checks = c if typeof(c) == TYPE_DICTIONARY else {}
	var shown := 0
	var total := 0
	for d in Save.habit_defs:
		var ad = d.get("active_days", [])
		if typeof(ad) != TYPE_ARRAY or col >= ad.size() or not bool(ad[col]):
			continue
		total += 1
		if shown >= LIST_MAX:
			continue
		var arr = checks.get(str(int(d.get("id", 0))), [])
		var checked: bool = typeof(arr) == TYPE_ARRAY and col < arr.size() and bool(arr[col])
		_item(_habit_box, str(d.get("title", "")), checked)
		shown += 1
	if total == 0:
		_line(_habit_box, tr("HOME_HABIT_EMPTY"), true)
	elif total > shown:
		_line(_habit_box, tr("HOME_MORE").format({"n": total - shown}), true)


# ── 집중: 오늘 집중한 분과 횟수 ──

func _refresh_focus() -> void:
	var seconds := 0
	var n := 0
	for e in Save.activity_entries_for(DateUtil.today_iso()):
		if SESSION_TYPES.has(str(e.get("type", ""))):
			seconds += int(e.get("seconds", 0))
			n += 1
	if n == 0:
		_focus_label.text = tr("HOME_FOCUS_EMPTY")
		_focus_label.theme_type_variation = &"VgMutedLabel"
		return
	_focus_label.theme_type_variation = &""
	_focus_label.text = tr("HOME_FOCUS_VALUE").format({"min": maxi(1, int(round(seconds / 60.0))), "n": n})


# ── 만들기 ──

## 누르면 target 도구로 가는 카드. 안쪽 상자를 돌려준다
func _card(parent: Control, title_key: String, target: StringName) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"VgCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			navigate_requested.emit(target))
	parent.add_child(card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(outer)
	var title := Label.new()
	title.theme_type_variation = &"VgMutedLabel"
	title.text = tr(title_key)
	outer.add_child(title)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(box)
	return box


func _sub(box: VBoxContainer, key: String) -> void:
	var l := Label.new()
	l.theme_type_variation = &"VgMutedLabel"
	l.add_theme_font_size_override("font_size", 12)
	l.text = tr(key)
	box.add_child(l)


func _list(box: VBoxContainer, titles: Array[String], done: bool) -> void:
	for i in mini(titles.size(), LIST_MAX):
		_item(box, titles[i], done)
	if titles.size() > LIST_MAX:
		_line(box, tr("HOME_MORE").format({"n": titles.size() - LIST_MAX}), true)


func _item(box: VBoxContainer, text: String, done: bool) -> void:
	var l := Label.new()
	l.text = ("✓ " if done else "· ") + text
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	if done:
		l.modulate = C_DONE
	box.add_child(l)


func _line(box: VBoxContainer, text: String, muted: bool) -> void:
	var l := Label.new()
	l.text = text
	if muted:
		l.theme_type_variation = &"VgMutedLabel"
	box.add_child(l)


func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		box.remove_child(c)                  # 같은 프레임에 트리에서 빼고 지운다(docs/architecture/list-rebuild.md)
		c.queue_free()
