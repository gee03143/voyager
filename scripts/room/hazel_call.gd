extends Node

## 헤이즐 부르기 재생기(docs/specs/hazel-room.md 의 "헤이즐 부르기").
## 방을 누르면 시메지 루트가 만든다. 셸 창에 대화 모드를 붙이고, 헤이즐이 들어와 대화 라우팅을 한 뒤 나간다.
##
## 대화 내용은 CompanionEngine 의 talk_open / talk_node 를 그대로 쓴다. 쪽지가 하던 대화가 여기로 옮겨왔다.
## 시메지를 숨기고 되살리는 것은 루트가 한다. 여기는 셸 창 안만 맡는다.
##
## 셸이 닫히면 중단한다. 답을 받은 직후마다 aborted 를 보고 그 자리에서 멈춘다.

signal ended

const DIALOGUE_SCRIPT := preload("res://scripts/onboarding/dialogue_mode.gd")

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


func start(shell: Window, main_shell: Node) -> void:
	_main_shell = main_shell
	_dialogue = DIALOGUE_SCRIPT.new()
	shell.add_child(_dialogue)                   # MainShell 뒤에 붙어 위에 그려진다
	shell.close_requested.connect(_dialogue.abort)
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


func _text(r: Dictionary) -> String:
	return tr(str(r["message_key"])).format(r["message_args"])
