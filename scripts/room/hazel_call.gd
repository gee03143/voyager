extends Node

## 헤이즐 부르기 재생기(docs/specs/hazel-room.md 의 "헤이즐 부르기").
## 방을 누르면 시메지 루트가 만든다. 셸 창에 대화 모드를 붙이고, 헤이즐이 들어와 대화 라우팅을 한 뒤 나간다.
##
## 대화 내용은 CompanionEngine 의 talk_open / talk_node 를 그대로 쓴다. 쪽지가 하던 대화가 여기로 옮겨왔다.
## 시메지를 숨기고 되살리는 것은 루트가 한다. 여기는 셸 창 안만 맡는다.
##
## 셸이 닫히면 중단한다. 답을 받은 직후마다 aborted 를 보고 그 자리에서 멈춘다.
##
## 홈에서 부르면 대화가 곧장 하루 판정으로 열린다(docs/specs/day-verdict.md).

signal ended

const DIALOGUE_SCRIPT := preload("res://scripts/onboarding/dialogue_mode.gd")
const PROPS := preload("res://scripts/onboarding/hazel_props.gd")
const FACE := preload("res://scripts/companion/shimeji_view.gd").Face

const CUSTOM_MAX := 20                           # 직접 적는 이름의 글자 수. 이름이지 일지가 아니다
const TRUNK_GAP := 70.0                          # 트렁크 앞에 설 때 트렁크 가운데에서 떨어지는 거리. F6에서 눈으로 조정할 값

## 판정 선택지. 고른 순서대로 종류가 된다(DayVerdict.KINDS)
const VERDICT_PICKS := [
	["held", "VERDICT_HELD"],
	["endured", "VERDICT_ENDURED"],
	["drifted", "VERDICT_DRIFTED"],
	["custom", "VERDICT_OPT_CUSTOM"],
]

## 대화가 안내하는 도구. 값은 MainShell.NAV_TARGETS 의 키다
const GOTO_TARGETS := {
	CompanionEngine.Action.GOTO_TODO: &"todo",
	CompanionEngine.Action.GOTO_HABIT: &"habit",
	CompanionEngine.Action.GOTO_TIMER: &"timer",
	CompanionEngine.Action.GOTO_RECORD: &"record",
	CompanionEngine.Action.GOTO_JOURNAL: &"journal",
}

var _dialogue: DIALOGUE_SCRIPT
var _main_shell: Node


func start(shell: Window, main_shell: Node, verdict := false) -> void:
	_main_shell = main_shell
	_dialogue = DIALOGUE_SCRIPT.new()
	shell.add_child(_dialogue)                   # MainShell 뒤에 붙어 위에 그려진다
	shell.close_requested.connect(_dialogue.abort)
	if verdict:
		await _play_verdict()
	else:
		await _play()
	shell.close_requested.disconnect(_dialogue.abort)
	shell.remove_child(_dialogue)                # 같은 프레임에 트리에서 빼고 지운다(docs/architecture/list-rebuild.md)
	_dialogue.queue_free()
	_dialogue = null
	ended.emit()


func _play() -> void:
	var d := _dialogue
	await get_tree().process_frame               # 대화 모드가 창 크기를 받은 뒤에 자리를 잡는다
	await d.enter_from_left(d.size.x * DIALOGUE_SCRIPT.HAZEL_AT, false)
	d.hazel.walk_dir = 1                         # 선택지가 뜨는 오른쪽을 본다
	await d.wait(0.3)
	var r := CompanionEngine.talk_open(Companion.today_done_count(), Companion.is_first_time())
	var goto := &""
	while true:
		await d.say(_text(r), false, tr("ONB_SPEAKER_HAZEL"))
		var opts: Array = r["options"]
		var labels := []
		for o in opts:
			labels.append(tr(str(o["key"])))
		var pick := await d.choose(labels)
		if d.aborted or pick < 0:
			return
		await d.user_says(labels[pick])
		var o: Dictionary = opts[pick]
		var action := int(o["action"])
		if action == CompanionEngine.Action.TALK_NODE:
			r = CompanionEngine.talk_node(o.get("arg", &""), Companion.habit_today())
			continue
		goto = GOTO_TARGETS.get(action, &"")     # 넘어가기(DISMISS)면 안내 없이 끝난다
		break
	if d.aborted:
		return
	if goto != &"":
		_main_shell.navigate(goto)               # 대화 모드가 덮고 있는 동안 바꿔 둔다. 걷히면 그 도구가 보인다
	await d.exit_left()
	await d.dismiss()


## 하루 판정. 헤이즐이 수첩을 펴고 이름을 묻는다. 받아 적어 방의 트렁크에 넣고 나간다
func _play_verdict() -> void:
	var d := _dialogue
	await get_tree().process_frame
	await d.enter_from_left(d.size.x * DIALOGUE_SCRIPT.HAZEL_AT, false)
	d.hazel.walk_dir = 1
	await d.wait(0.3)
	if not Save.verdict.can_judge(DateUtil.now_unix()):
		# 홈이 열어둔 사이에 판정이 이미 들어갔다. 한 번 정하면 끝이다
		d.set_face(FACE.SOFT)
		await d.say(tr("VERDICT_ALREADY"), false, tr("ONB_SPEAKER_HAZEL"))
		await _leave()
		return
	Sound.play_sfx(&"book_open")
	d.props.book = PROPS.Book.OPEN
	d.props.pencil = true
	d.set_face(FACE.THINK)
	await d.say(tr("VERDICT_ASK"), false, tr("ONB_SPEAKER_HAZEL"))
	var labels := []
	for p in VERDICT_PICKS:
		labels.append(tr(p[1]))
	labels.append(tr("VERDICT_OPT_LATER"))
	var pick := await d.choose(labels)
	if d.aborted or pick < 0:
		return
	await d.user_says(labels[pick])
	if pick >= VERDICT_PICKS.size():
		await _verdict_later()
		return
	var kind: String = VERDICT_PICKS[pick][0]
	var text := ""
	if kind == "custom":
		d.set_face(FACE.SOFT)
		text = await d.ask_name(tr("VERDICT_CUSTOM_HINT"), tr("VERDICT_CUSTOM_OK"), tr("VERDICT_CUSTOM_BACK"), "", CUSTOM_MAX)
		if d.aborted:
			return
		if text == "":
			await _verdict_later()
			return
		await d.user_says(text)
	# 받아 적는다. 또박또박, 빠르지 않다
	d.hide_bubble()
	d.set_face(FACE.SOFT)
	Sound.play_sfx_repeat(&"write", 4, 0.3)
	await d.wait(1.4)
	if d.aborted:
		return
	Save.verdict.add(kind, text)
	Sound.play_sfx(&"page")                      # 그 장을 찢어 접는다
	d.props.pencil = false
	d.props.book = PROPS.Book.HELD
	await d.wait(0.4)
	d.set_face(FACE.SOFT)
	await d.say(tr("VERDICT_KEEP"), false, tr("ONB_SPEAKER_HAZEL"))
	# 방 구석의 트렁크에 넣는다
	d.hide_bubble()
	await d.walk_to(d.trunk_spot_x() - TRUNK_GAP)
	Sound.play_sfx(&"lid")
	await d.quick_reach()
	await d.wait(0.3)
	d.props.book = PROPS.Book.NONE
	await _leave()


## 지금은 이름을 붙이지 않는다. 동의하지 않고 문만 열어둔다 — 수첩을 보이는 곳에 둔다(페르소나 §4)
func _verdict_later() -> void:
	var d := _dialogue
	d.props.pencil = false
	d.props.book = PROPS.Book.HELD
	d.set_face(FACE.SOFT)
	await d.say(tr("VERDICT_LATER_RE"), false, tr("ONB_SPEAKER_HAZEL"))
	d.props.book = PROPS.Book.NONE
	await _leave()


func _leave() -> void:
	var d := _dialogue
	if d.aborted:
		return
	d.set_face(FACE.NONE)
	await d.exit_left()
	await d.dismiss()


func _text(r: Dictionary) -> String:
	return tr(str(r["message_key"])).format(r["message_args"])
