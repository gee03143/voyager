extends Node

# 컴패니언 이벤트 접점 — 뷰는 "이런 일이 있었다"만 알리고 맥락 계산은 여기서 한다.
# 배너는 이 시그널만 듣는다(스왑되는 뷰와 배너가 서로를 모름) — Clock이 세션에서 맡는 역할과 같은 자리.
# 문구 결정은 CompanionEngine(순수), 화면 표시는 Banner.

signal todo_completed(ctx: Dictionary)
signal habit_completed(ctx: Dictionary)

const VITALITY_TYPES := ["todo", "pomodoro_session", "timer"]   # 습관은 개수가 아니라 완료율로 따로 본다

# 할 일 완료 보고. **활동 로그에 적재한 뒤에** 부를 것 — first_today가 방금 것까지 세기 때문
func notify_todo_completed(event_id: int, todo: Todo, group: TodoGroup) -> void:
	todo_completed.emit({
		"event_id": event_id,
		"group": group.display_name(),
		"remaining": _remaining(group),
		"first_today": _todo_count_today() <= 1,
		"age_days": _age_days(todo),
		"title": todo.text,
	})
	
# 습관 체크 보고. **habit_weeks에 반영한 뒤에** 부를 것 — remaining이 방금 것까지 반영해 계산된다
func notify_habit_completed(habit: Habit) -> void:
	var t := habit_today()
	habit_completed.emit({
		"title": habit.title,
		"remaining": int(t["active"]) - int(t["done"]),
		"gap_days": _habit_gap_days(habit.id),
		"expected_gap": _expected_gap(habit.active_days),
	})

# --- 대기 상태(활력 축)용 조회 ---
func today_done_count() -> int:
	var n := 0
	for e in Save.activity_entries_for(DateUtil.today_iso()):
		if VITALITY_TYPES.has(str(e.get("type", ""))):
			n += 1
	return n

func last_activity() -> Dictionary:                           # 오늘 마지막 행동. 없으면 빈 사전
	var out := {}
	for e in Save.activity_entries_for(DateUtil.today_iso()):
		if VITALITY_TYPES.has(str(e.get("type", ""))):
			out = e                                           # ts 오름차순이라 마지막 대입이 곧 최신
	return out

# --- 내부 계산 ---
func _remaining(group: TodoGroup) -> int:
	var n := 0
	for t in group.tasks:
		if not t.done:
			n += 1
	return n

func _todo_count_today() -> int:
	var today := DateUtil.today_iso()
	var n := 0
	for e in Save.activity_log.events:
		if str(e.get("type", "")) == "todo" and DateUtil.local_day_iso(int(e.get("ts", 0))) == today:
			n += 1
	return n

func _age_days(todo: Todo) -> int:
	if todo.created_ts <= 0:
		return -1                                             # 구버전 데이터 — 모름
	return -DateUtil.days_until(DateUtil.local_day_iso(todo.created_ts))   # 과거 날짜라 음수 → 부호 반전

func _habit_gap_days(habit_id: int) -> int:                   # 마지막 체크(오늘 제외)로부터 며칠. -1 = 첫 기록
	var today := DateUtil.today_iso()
	var last := ""
	for wk in Save.habit_weeks:
		var c = wk.get("checks", {})
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var arr = c.get(str(habit_id), [])
		if typeof(arr) != TYPE_ARRAY:
			continue
		for d in 7:
			if d < arr.size() and bool(arr[d]):
				var iso := DateUtil.add_days(str(wk.get("week_start", "")), d)
				if iso < today and iso > last:
					last = iso
	if last == "":
		return -1
	return -DateUtil.days_until(last)                         # 과거 날짜라 음수 → 부호 반전

func _expected_gap(active_days: Array) -> int:                # 이 습관의 정상 간격(요일 설정상 최대 몇 칸 비는지)
	var days: Array[int] = []
	for i in 7:
		if i < active_days.size() and bool(active_days[i]):
			days.append(i)
	if days.size() <= 1:
		return 7                                              # 주 1회 이하면 7일이 정상
	var worst := 0
	for i in days.size():
		var cur: int = days[i]
		var nxt: int = days[(i + 1) % days.size()]
		worst = maxi(worst, (nxt - cur) if nxt > cur else (nxt + 7 - cur))
	return worst

func is_first_time() -> bool:
	return Save.activity_log.events.is_empty()      # 기록이 통째로 비면 첫 사용
	
func habit_today() -> Dictionary:                             # 오늘 활성 습관 수와 그중 체크된 수
	var col := (int(Time.get_date_dict_from_system().weekday) + 6) % 7   # 일0..토6 → 월요일 시작
	var checks := _week_checks(DateUtil.monday_iso())
	var active := 0
	var done := 0
	for d in Save.habit_defs:
		var ad = d.get("active_days", [])
		if typeof(ad) != TYPE_ARRAY or col >= ad.size() or not bool(ad[col]):
			continue
		active += 1
		var arr = checks.get(str(int(d.get("id", 0))), [])
		if typeof(arr) == TYPE_ARRAY and col < arr.size() and bool(arr[col]):
			done += 1
	return {"active": active, "done": done}

func _week_checks(week_start: String) -> Dictionary:
	for wk in Save.habit_weeks:
		if str(wk.get("week_start", "")) == week_start:
			var c = wk.get("checks", {})
			return c if typeof(c) == TYPE_DICTIONARY else {}
	return {}
