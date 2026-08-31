class_name CompanionEngine
extends RefCounted

# 컴패니언 반응 결정 — Save·씬·노드를 모른다(순수 로직, 배선은 Banner 몫).
# 반환값은 "무엇을 말할지"(번역 키 + 채울 값)까지고, 문자열 조립·표시는 뷰가 한다.
# 이벤트를 어떻게 표기할지(구간·요약 라벨)는 여기가 아니라 ActivityFormat 담당.

enum Action { NOTE, DISMISS, GOTO_TODO, GOTO_HABIT, GOTO_TIMER, GOTO_RECORD, GOTO_JOURNAL, TALK, TALK_NODE }

const MIN_SHOWN_MINUTES := 1        # 짧은 테스트 세션이 "0분"으로 뜨지 않게
const MANY_THRESHOLD := 3           # 오늘 이만큼 하면 "많음"
const ALMOST_REMAINING := 2         # 그룹에 이만큼 남으면 "거의 다"
const LONG_AGO_DAYS := 7            # 이만큼 묵으면 "오래 묵은 것"
const HABIT_BACK_MIN_DAYS := 3      # 정상 간격을 넘고 이만큼은 비어야 "재개"로 본다

const SESSION_TYPES := ["pomodoro_session", "timer"]

static func idle(done_count: int, last: Dictionary, habit: Dictionary) -> Dictionary:
	var session := SESSION_TYPES.has(str(last.get("type", "")))
	var go := {"key": "COMPANION_GOTO_TODO", "action": Action.GOTO_TODO}
	if session:
		go = {"key": "COMPANION_GOTO_TIMER", "action": Action.GOTO_TIMER}   # 하던 걸 이어가게
	var talk := {"key": "COMPANION_OPT_TALK", "action": Action.TALK}
	var to_todo := {"key": "COMPANION_GOTO_TODO", "action": Action.GOTO_TODO}
	var h_active := int(habit.get("active", 0))
	var h_left := h_active - int(habit.get("done", 0))
	if done_count <= 0:                             # 아직 흐름이 없을 때만 기준선을 꺼낸다
		if h_left > 0:
			return _reaction("COMPANION_IDLE_HABIT_LEFT", {"n": h_left}, false,
				[{"key": "COMPANION_GOTO_HABIT", "action": Action.GOTO_HABIT}, talk])
		if h_active > 0:                            # 습관은 채웠는데 그 외엔 아직
			return _reaction("COMPANION_IDLE_HABIT_CLEAR", {}, false, [to_todo, talk])
		return _reaction("COMPANION_IDLE_NONE_DAY", {}, false, [to_todo, talk])
	if done_count >= MANY_THRESHOLD:
		return _reaction("COMPANION_IDLE_MANY", {"n": done_count}, false,
			[{"key": "COMPANION_GOTO_RECORD", "action": Action.GOTO_RECORD}, talk])
	if session:
		return _reaction("COMPANION_IDLE_SOME_FOCUS", {"min": _focus_minutes(last)}, false, [go, talk])
	return _reaction("COMPANION_IDLE_SOME_ITEM", {"n": done_count}, false, [go, talk])

# --- 함께 있음 ---
static func focusing() -> Dictionary:
	return _reaction("COMPANION_FOCUSING")          # 진행 중엔 방해하지 않음 — 선택지 없음

static func session_done(e: Dictionary) -> Dictionary:
	return _reaction("COMPANION_SESSION_DONE", {"min": _focus_minutes(e)}, true, [
		{"key": "COMPANION_OPT_NOTE", "action": Action.NOTE},
		{"key": "COMPANION_OPT_SKIP", "action": Action.DISMISS},
	])
	
# --- 할 일 완료 (사다리: 먼저 걸리는 것이 이긴다) ---
static func todo_done(ctx: Dictionary) -> Dictionary:
	var opts := [{"key": "COMPANION_OPT_NOTE", "action": Action.NOTE}]
	var remaining := int(ctx.get("remaining", 0))
	var age := int(ctx.get("age_days", -1))
	if remaining <= 0:
		return _reaction("COMPANION_TODO_GROUP_CLEAR", {"group": str(ctx.get("group", ""))}, true, opts)
	if bool(ctx.get("first_today", false)):
		return _reaction("COMPANION_TODO_FIRST_TODAY", {}, false, opts)
	if age >= LONG_AGO_DAYS:
		return _reaction("COMPANION_TODO_LONG_AGO", {"days": age}, true, opts)
	if remaining <= ALMOST_REMAINING:
		return _reaction("COMPANION_TODO_ALMOST", {"n": remaining}, false, opts)
	return _reaction("COMPANION_TODO_DONE", {}, false, opts)

# --- 습관 완료 (사다리) ---
# 습관 이벤트는 activity_log에 없어 id가 없다 → 노트를 달 수 없으므로 선택지는 넘어가기뿐
static func habit_done(ctx: Dictionary) -> Dictionary:
	var opts := [_skip()]
	var remaining := int(ctx.get("remaining", 0))
	var gap := int(ctx.get("gap_days", -1))
	var expected := int(ctx.get("expected_gap", 1))
	if remaining <= 0:
		return _reaction("COMPANION_HABIT_ALL_DONE", {}, true, opts)
	if gap < 0:
		return _reaction("COMPANION_HABIT_FIRST_EVER", {}, false, opts)
	if gap > expected and gap >= HABIT_BACK_MIN_DAYS:
		return _reaction("COMPANION_HABIT_BACK", {"days": gap}, true, opts)
	return _reaction("COMPANION_HABIT_LEFT", {"n": remaining}, false, opts)

# --- 내부 ---
static func _focus_minutes(e: Dictionary) -> int:
	return maxi(MIN_SHOWN_MINUTES, int(round(int(e.get("seconds", 0)) / 60.0)))

static func _reaction(key: String, args: Dictionary = {}, reward := false, options: Array = []) -> Dictionary:
	return {"message_key": key, "message_args": args, "reward": reward, "options": options}

# --- 대화 (사용자가 먼저 말을 걸었을 때) ---
# 노드는 표로 둔다 — 갈래를 늘릴 때 코드가 아니라 표와 CSV만 손대면 되도록.
# 선택지의 arg = 다음 노드 id. "그냥 쉴래"의 행선지가 상황마다 다른 게 페르소나의 핵심이다.

const TALK_OPEN := {
	&"first": {
		"key": "COMPANION_TALK_FIRST",
		"options": [
			{"key": "COMPANION_OPT_SEE_TODO", "action": Action.TALK_NODE, "arg": &"follow_todo"},
			{"key": "COMPANION_OPT_REST", "action": Action.TALK_NODE, "arg": &"stand_start"},
		]},
	&"before": {
		"key": "COMPANION_TALK_BEFORE",
		"options": [
			{"key": "COMPANION_OPT_SEE_TODO", "action": Action.TALK_NODE, "arg": &"follow_todo"},
			{"key": "COMPANION_OPT_SHORT_FOCUS", "action": Action.TALK_NODE, "arg": &"follow_focus"},
			{"key": "COMPANION_OPT_NOT_GREAT", "action": Action.TALK_NODE, "arg": &"empathy"},
			{"key": "COMPANION_OPT_REST", "action": Action.TALK_NODE, "arg": &"reask_start"},
		]},
	&"during": {
		"key": "COMPANION_TALK_DURING",
		"options": [
			{"key": "COMPANION_OPT_SEE_TODO", "action": Action.TALK_NODE, "arg": &"follow_todo"},
			{"key": "COMPANION_OPT_SHORT_FOCUS", "action": Action.TALK_NODE, "arg": &"follow_focus"},
			{"key": "COMPANION_OPT_NOT_GREAT", "action": Action.TALK_NODE, "arg": &"empathy"},
			{"key": "COMPANION_OPT_REST", "action": Action.TALK_NODE, "arg": &"reask_wrap"},
		]},
	&"enough": {
		"key": "COMPANION_TALK_ENOUGH",
		"options": [
			{"key": "COMPANION_OPT_SEE_RECORD", "action": Action.TALK_NODE, "arg": &"follow_record"},
			{"key": "COMPANION_OPT_WRITE_JOURNAL", "action": Action.TALK_NODE, "arg": &"follow_journal_wrap"},
			{"key": "COMPANION_OPT_NOT_GREAT", "action": Action.TALK_NODE, "arg": &"empathy"},
			{"key": "COMPANION_OPT_REST", "action": Action.TALK_NODE, "arg": &"reask_wrap"},
		]},
}

const TALK_NODES := {
	&"empathy": {
		"key": "COMPANION_EMPATHY",
		"options": [
			{"key": "COMPANION_OPT_SHORT_FOCUS", "action": Action.TALK_NODE, "arg": &"follow_focus"},
			{"key": "COMPANION_OPT_WRITE_JOURNAL", "action": Action.TALK_NODE, "arg": &"follow_journal_vent"},
			{"key": "COMPANION_OPT_REST", "action": Action.TALK_NODE, "arg": &"reask_low"},
		]},
	&"reask_start": {
		"key": "COMPANION_REASK_START",
		"options": [
			{"key": "COMPANION_OPT_SHORT_FOCUS", "action": Action.TALK_NODE, "arg": &"follow_focus"},
			{"key": "COMPANION_OPT_REST", "action": Action.TALK_NODE, "arg": &"stand_start"},
		]},
	&"reask_low": {
		"key": "COMPANION_REASK_LOW",
		"options": [
			{"key": "COMPANION_OPT_SHORT_FOCUS", "action": Action.TALK_NODE, "arg": &"follow_focus"},
			{"key": "COMPANION_OPT_REST", "action": Action.TALK_NODE, "arg": &"stand_start"},
		]},
	&"reask_wrap": {
		"key": "COMPANION_REASK_WRAP",
		"options": [
			{"key": "COMPANION_OPT_WRITE_JOURNAL", "action": Action.TALK_NODE, "arg": &"follow_journal_wrap"},
			{"key": "COMPANION_OPT_PLAN_TOMORROW", "action": Action.TALK_NODE, "arg": &"follow_plan"},
			{"key": "COMPANION_OPT_REST", "action": Action.TALK_NODE, "arg": &"stand_wrap"},
		]},
	# 후속 — goto가 있으면 안내 버튼 + 넘어가기로 자동 구성된다
	&"follow_todo": {"key": "COMPANION_FOLLOW_TODO", "goto": Action.GOTO_TODO, "goto_key": "COMPANION_GOTO_TODO"},
	&"follow_focus": {"key": "COMPANION_FOLLOW_FOCUS", "goto": Action.GOTO_TIMER, "goto_key": "COMPANION_GOTO_TIMER"},
	&"follow_record": {"key": "COMPANION_FOLLOW_RECORD", "goto": Action.GOTO_RECORD, "goto_key": "COMPANION_GOTO_RECORD"},
	&"follow_journal_vent": {"key": "COMPANION_FOLLOW_JOURNAL_VENT", "goto": Action.GOTO_JOURNAL, "goto_key": "COMPANION_GOTO_JOURNAL"},
	&"follow_journal_wrap": {"key": "COMPANION_FOLLOW_JOURNAL_WRAP", "goto": Action.GOTO_JOURNAL, "goto_key": "COMPANION_GOTO_JOURNAL"},
	&"follow_plan": {"key": "COMPANION_FOLLOW_PLAN", "goto": Action.GOTO_TODO, "goto_key": "COMPANION_GOTO_TODO"},
	&"follow_habit": {"key": "COMPANION_FOLLOW_HABIT", "goto": Action.GOTO_HABIT, "goto_key": "COMPANION_GOTO_HABIT"},
	# 물러섬 — 동의는 안 하고 문만 열어둔다
	&"stand_start": {"key": "COMPANION_STAND_START"},
	&"stand_wrap": {"key": "COMPANION_STAND_WRAP"},
}

static func talk_open(done_count: int, first_time: bool) -> Dictionary:
	var id := &"before"
	if first_time:
		id = &"first"
	elif done_count >= MANY_THRESHOLD:
		id = &"enough"
	elif done_count > 0:
		id = &"during"
	var n: Dictionary = TALK_OPEN[id]
	return _reaction(str(n["key"]), {}, false, n["options"])

static func talk_node(id: StringName, habit: Dictionary = {}) -> Dictionary:
	var h_left := int(habit.get("active", 0)) - int(habit.get("done", 0))
	if h_left > 0 and (id == &"reask_start" or id == &"reask_wrap"):
		# 하루를 닫으려는 순간 — 여기서만 기준선을 짚는다(흐름 중엔 안 꺼낸다)
		return _reaction("COMPANION_REASK_WRAP_HABIT", {"m": h_left}, false, [
			{"key": "COMPANION_OPT_SEE_HABIT", "action": Action.TALK_NODE, "arg": &"follow_habit"},
			{"key": "COMPANION_OPT_REST", "action": Action.TALK_NODE, "arg": &"stand_start"},
		])
	var n: Dictionary = TALK_NODES.get(id, {})
	if n.is_empty():
		return _reaction("COMPANION_STAND_START", {}, false, [_skip()])   # 알 수 없는 노드 → 안전하게 종료
	if n.has("goto"):
		return _reaction(str(n["key"]), {}, false,
			[{"key": str(n["goto_key"]), "action": int(n["goto"])}, _skip()])
	var opts: Array = n.get("options", [])
	return _reaction(str(n["key"]), {}, false, opts if not opts.is_empty() else [_skip()])

static func _skip() -> Dictionary:
	return {"key": "COMPANION_OPT_SKIP", "action": Action.DISMISS}
