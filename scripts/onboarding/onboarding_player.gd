extends Node

## 온보딩 재생기. 무엇을 어떤 순서로 보여줄지 정한다(docs/specs/onboarding.md).
## 대사 전문은 docs/companion-butler-draft.md, 문자열은 translations.csv 의 ONB_*.
##
## 무대가 둘이다. 바탕화면 무대(desktop_stage.gd)와 셸 창의 대화 모드(dialogue_mode.gd).
## 시메지 루트가 만들고 ended 를 받는다. 셸 창·MainShell·바탕화면 무대는 넘겨받기만 한다.
## onboarded 저장과 배너 복구, 시메지 복귀는 루트가 한다. 호칭과 예시 할 일은 여기서 저장한다.
##
## 셸이 닫히면 중단한다. 답을 받은 직후마다 _stop() 을 보고 그 자리에서 멈춘다 —
## 저장처럼 흔적을 남기는 일은 항상 답 뒤에 있으므로 중단 뒤에 일어나지 않는다.
## 바탕화면 단계에서는 셸이 아직 안 열려 있어 닫을 것이 없다.

signal ended(completed: bool)

const DIALOGUE_SCRIPT := preload("res://scripts/onboarding/dialogue_mode.gd")
const STAGE_SCRIPT := preload("res://scripts/onboarding/desktop_stage.gd")
const PROPS := preload("res://scripts/onboarding/hazel_props.gd")
const FACE := preload("res://scripts/companion/shimeji_view.gd").Face
const TOOL := preload("res://scripts/onboarding/tool_icon.gd")
const PUSH_GAP := 150.0                         # 트렁크를 밀 때 헤이즐과 트렁크 사이
const STEP_BACK := 70.0                         # 한 걸음 물러나 본다
const HALF_SPAN := 28.0                         # 반 뼘

var _dialogue: DIALOGUE_SCRIPT
var _desk: STAGE_SCRIPT
var _shell: Window
var _main_shell: Node


func start(shell: Window, main_shell: Node, desk: STAGE_SCRIPT) -> void:
	_shell = shell
	_main_shell = main_shell
	_desk = desk
	shell.hide()                                 # 1비트 앞부분은 바탕화면이다. 헤이즐을 열어줘야 셸이 열린다
	_dialogue = DIALOGUE_SCRIPT.new()
	shell.add_child(_dialogue)                   # MainShell 뒤에 붙어 위에 그려진다
	# 헤이즐이 오기 전의 방이다. 트렁크는 헤이즐이 5비트에 놓고, 수첩은 첫날을 적은 뒤에 생긴다
	_dialogue.room.show_trunk = false
	_dialogue.room.show_notebooks = false
	shell.close_requested.connect(_dialogue.abort)
	await _play()
	var completed := not _dialogue.aborted
	shell.close_requested.disconnect(_dialogue.abort)
	shell.remove_child(_dialogue)                # 같은 프레임에 트리에서 빼고 지운다(docs/architecture/list-rebuild.md)
	_dialogue.queue_free()
	_dialogue = null
	ended.emit(completed)


func _stop() -> bool:
	return _dialogue.aborted


func _play() -> void:
	await _beat1_desktop()
	await _enter_shell()
	await _beat1_shell()
	if _stop():
		return
	await _beat2()
	if _stop():
		return
	await _beat3()
	if _stop():
		return
	await _beat4()
	if _stop():
		return
	await _beat5()


# ── 1비트 · 부임 (바탕화면) ──

func _beat1_desktop() -> void:
	var s := _desk
	var w := float(STAGE_SCRIPT.STAGE_SIZE.x)
	s.open_stage()
	await s.wait(3.0)                            # 평소. 아무 일도 없다
	# 전조. 화면 가장자리 밖에서 트렁크가 밀려 들어온다
	s.place_trunk_offstage()
	await s.slide_trunk(w - 50, 1.3)
	await s.wait(1.15)
	await s.slide_trunk(w - 140, 1.1)
	await s.wait(1.25)
	# 등장. 트렁크 뒤를 지나 한 발 옆으로 나온다
	s.appear_offstage()
	await s.walk_to(w - 260)
	await s.wait(0.6)
	await s.look_around()
	await s.shake_off()
	await s.wait(0.5)
	# 트렁크를 끌고 화면 쪽으로 걸어와 두드린다
	await s.walk_to(w * 0.42, true)
	await s.wait(0.6)
	s.face_front()
	await s.knock(3)
	await s.wait(0.4)
	await s.narrate(tr("ONB_B1_NARR_KNOCK"))

	var full := true
	while true:
		var labels := [tr("ONB_B1_OPT_OPEN")]
		if full:
			labels += [tr("ONB_B1_OPT_WHO"), tr("ONB_B1_OPT_IGNORE")]
		s.click_opens = true                     # 헤이즐을 직접 눌러도 열어준다
		var pick := await s.choose(labels)
		s.click_opens = false
		if pick == 0:
			break
		full = false                             # 반응을 본 뒤에는 열어주는 것만 남는다
		await s.user_says(labels[pick])
		await s.wait(0.6)
		if pick == 1:
			s.set_face(FACE.FLUSTERED)
			await s.say(tr("ONB_B1_BUTLER"), true, "???")
			await s.narrate(tr("ONB_B1_NARR_HEARS"))
			await s.wait(0.3)
			await s.knock(1)
			s.set_face(FACE.NONE)
		else:
			await s.wait(3.0)                    # 아무 일도 없다
			await s.show_card(tr("ONB_B1_CARD"))
			await s.wait(1.6)
			await s.narrate(tr("ONB_B1_NARR_WAITS"))
			await s.hide_card()


## 열어줬다. 셸이 대화 모드로 열리고 헤이즐이 트렁크를 끌고 걸어 나가 창 안으로 들어간다
func _enter_shell() -> void:
	var s := _desk
	_place_shell_on_stage_screen()
	_shell.show()
	_shell.grab_focus()                          # move_to_foreground 는 4.6 에서 폐기 예정이다(실행 경고로 확인)
	await s.wait(0.8)
	await s.walk_to(-240.0, true)                # 트렁크까지 창 밖으로 나간다
	s.close_stage()
	var d := _dialogue
	await d.enter_from_left(d.size.x * DIALOGUE_SCRIPT.HAZEL_AT)
	d.hazel.walk_dir = 1


## 셸을 바탕화면 무대와 같은 모니터의 가운데에 둔다.
## Screen 은 셸 자신이 있던 모니터 기준으로 가운데에 놓으므로(screen.gd 의 _center), 모니터가 여럿이면 엇갈릴 수 있다
func _place_shell_on_stage_screen() -> void:
	var screen := _desk.get_window().current_screen
	_shell.current_screen = screen
	var rect := DisplayServer.screen_get_usable_rect(screen)
	_shell.position = rect.position + (rect.size - _shell.size) / 2


# ── 1비트 · 부임 (셸 안) ──

func _beat1_shell() -> void:
	var d := _dialogue
	await d.wait(0.4)
	await d.wipe_feet()
	await d.wait(0.3)
	await d.bow()
	d.set_face(FACE.FLUSTERED, false, true)
	await d.say(tr("ONB_B1_HELLO"), false, "???")
	d.set_face(FACE.SOFT)
	await d.say(tr("ONB_B1_JOB"))

	var labels := [tr("ONB_B1_OPT_WHO_SENT"), tr("ONB_B1_OPT_JOB"), tr("ONB_B1_OPT_LOOK")]
	var pick := await d.choose(labels)
	if _stop():
		return
	await _answer(labels[pick])
	match pick:
		0:
			d.set_face(FACE.SOFT)
			await d.say(tr("ONB_B1_RE_NOBODY"))
			await d.hold(0.6)
			d.set_face(FACE.SHY, true)
			await d.say(tr("ONB_B1_RE_CAME"))
		1:
			d.set_face(FACE.SMILE)
			await d.say(tr("ONB_B1_RE_JOB"))
			await d.hold(0.6)
			d.set_face(FACE.FLUSTERED, false, true)
			await d.say(tr("ONB_B1_RE_SLOWLY"))
		2:
			d.set_face(FACE.SURPRISED)
			await d.hold(1.8)                # 둘 다 말이 없다
			d.set_face(FACE.SHY, true)
			await d.bow()

	d.hide_bubble()
	await d.wait(0.4)
	await d.straighten_trunk()
	d.hazel.walk_dir = 1
	d.set_face(FACE.SHY, true)
	await d.say(tr("ONB_B1_NAME"), false, "???")
	await d.flip_name(tr("ONB_SPEAKER_HAZEL"))
	await d.wait(0.5)
	d.trunk.opened = true
	Sound.play_sfx(&"latch")
	await d.wait(0.8)
	d.set_face(FACE.SMILE)
	await d.say(tr("ONB_B1_UNPACK"))


# ── 2비트 · 이유 ──

func _beat2() -> void:
	var d := _dialogue
	await d.wait(0.6)
	d.hide_bubble()
	d.set_face(FACE.NONE)
	# 짐을 푼다. 손이 빠르고 망설임이 없다
	await d.quick_reach()
	d.props.apron = true
	Sound.play_sfx(&"cloth")
	await d.wait(0.3)
	await d.quick_reach()
	d.props.book = PROPS.Book.HELD
	Sound.play_sfx(&"book_take")
	await d.wait(0.8)

	var labels := [tr("ONB_B2_ASK_WHY"), tr("ONB_B2_ASK_PEEK"), tr("ONB_B2_ASK_WHAT")]
	var pick := await d.choose(labels)
	if _stop():
		return
	await _answer(labels[pick])
	match pick:
		0:
			d.set_face(FACE.FLUSTERED, false, true)
			await d.say(tr("ONB_B2_RE_WHY"))
		1:
			d.props.book = PROPS.Book.RAISED  # 수첩을 들어 보인다
			d.set_face(FACE.SMILE)
			await d.say(tr("ONB_B2_RE_PEEK"))
			d.props.book = PROPS.Book.HELD
		2:
			d.set_face(FACE.THINK)
			await d.say(tr("ONB_B2_RE_WHAT"))

	# 왜
	d.set_face(FACE.SOFT)
	await d.say(tr("ONB_B2_DAYS"))
	await d.say(tr("ONB_B2_WINTER"))
	await d.hold(1.0)
	d.set_face(FACE.SMILE)
	await d.say(tr("ONB_B2_WARM"))
	d.set_face(FACE.SHY, true)
	await d.say(tr("ONB_B2_TRAINEE"))
	# 무엇을
	d.set_face(FACE.NONE)
	await d.say(tr("ONB_B2_HERE"))
	d.set_face(FACE.SOFT)
	await d.say(tr("ONB_B2_TODO"))
	await d.say(tr("ONB_B2_DAYEND"))
	d.set_face(FACE.SMILE)
	await d.say(tr("ONB_B2_EMPTY"))

	labels = [tr("ONB_B2_OPT_OK"), tr("ONB_B2_OPT_DOUBT"), tr("ONB_B2_OPT_BOOK")]
	pick = await d.choose(labels)
	if _stop():
		return
	await _answer(labels[pick])
	match pick:
		0:
			await d.hop()                # 꼬리가 한 번 크게 — 리그에 없어 몸으로 대신한다
			d.set_face(FACE.SMILE)
			await d.say(tr("ONB_B2_RE_OK"))
		1:
			d.set_face(FACE.SOFT)
			await d.say(tr("ONB_B2_RE_DOUBT"))
			await d.hold(1.5)            # 재촉하지 않고 기다린다
		2:
			d.props.book = PROPS.Book.OPEN   # 첫 장을 펼쳐 보인다. 비어 있다
			Sound.play_sfx(&"book_open")
			await d.wait(0.6)
			d.set_face(FACE.SMILE)
			await d.say(tr("ONB_B2_RE_BOOK"))


# ── 3비트 · 이름 ──

func _beat3() -> void:
	var d := _dialogue
	await d.wait(0.8)
	d.hide_bubble()
	d.set_face(FACE.NONE)
	d.props.book = PROPS.Book.OPEN       # 수첩 첫 장을 편다
	Sound.play_sfx(&"book_open")
	await d.wait(0.5)
	d.props.pencil = true
	await d.wait(0.4)
	# 연필을 깎는다. 손이 빠르다
	Sound.play_sfx_repeat(&"sharpen", 2, 0.35)
	await d.wait(0.35)
	await d.quick_reach()
	await d.wait(0.15)
	await d.quick_reach()
	await d.wait(0.65)
	d.set_face(FACE.THINK)
	await d.say(tr("ONB_B3_FIRST"))
	d.set_face(FACE.SOFT)
	await d.say(tr("ONB_B3_ASK"))

	# 적고 나서 보여주고 확인한다. 잘못 적었다고 하면 다시 받는다. 확인된 뒤에만 저장한다
	var prefill := ""
	while true:
		var nick := await d.ask_name(tr("ONB_B3_NAME_HINT"), tr("ONB_B3_OPT_TELL"), tr("ONB_B3_OPT_LATER"), prefill)
		if _stop():
			return
		if nick == "":
			_save_nickname("")
			await _beat3_blank()
			return
		await _beat3_write()
		d.props.book = PROPS.Book.OPEN   # 수첩을 돌려 유저 쪽으로 보여준다
		d.set_face(FACE.THINK)
		await d.say(tr("ONB_B3_CONFIRM").format({"name": nick}))
		var labels := [tr("ONB_B3_OPT_RIGHT"), tr("ONB_B3_OPT_WRONG")]
		var pick := await d.choose(labels)
		if _stop():
			return
		await _answer(labels[pick])
		if pick == 0:
			_save_nickname(nick)
			await _beat3_call(nick)
			return
		# 유저의 오타라도 헤이즐이 받아 간다 — 페르소나 §4 의 "덮어주기"
		d.set_face(FACE.FLUSTERED, false, true)
		await d.say(tr("ONB_B3_MISHEARD"))
		Sound.play_sfx_repeat(&"sharpen", 2, 0.3)
		await d.wait(0.35)
		await d.quick_reach()                # 연필 끝으로 줄을 긋는다
		await d.wait(0.55)
		d.set_face(FACE.SOFT)
		await d.say(tr("ONB_B3_AGAIN"))
		prefill = nick                       # 앞서 적은 이름이 든 채로 다시 받는다. 고치기만 하면 된다


func _save_nickname(nick: String) -> void:
	Save.settings.nickname = nick
	Save.settings.changed.emit()             # 전역 설정은 save-on-change


## 받아 적는다. 또박또박, 빠르지 않다
func _beat3_write() -> void:
	var d := _dialogue
	d.hide_bubble()
	d.set_face(FACE.SOFT)
	d.props.book = PROPS.Book.OPEN
	d.props.pencil = true
	Sound.play_sfx_repeat(&"write", 6, 0.3)
	await d.wait(1.95)
	await d.quick_reach()                    # 한 획을 고쳐 긋는다
	await d.wait(0.75)


func _beat3_call(nick: String) -> void:
	var d := _dialogue
	d.hide_bubble()
	d.props.pencil = false
	d.props.book = PROPS.Book.HELD           # 가슴에 안는다
	await d.wait(0.6)
	d.set_face(FACE.SHY, true)
	await d.say(tr("ONB_B3_CALL").format({"name": nick}))
	await d.hop()                            # 꼬리가 한 번 크게 — 리그에 없어 몸으로 대신한다
	await d.hold(0.5)
	await d.say(tr("ONB_B3_PRACTICE").format({"name": nick}))
	await d.narrate(tr("ONB_B3_NARR_PRACTICE"))
	d.set_face(FACE.SMILE)
	await d.say(tr("ONB_B3_MEMORIZED"))


func _beat3_blank() -> void:
	var d := _dialogue
	d.hide_bubble()
	await d.user_says(tr("ONB_B3_OPT_LATER"))
	await d.wait(0.5)
	d.set_face(FACE.SOFT)
	await d.say(tr("ONB_B3_OK"))
	d.props.pencil = false               # 연필을 내려놓는다
	await d.wait(0.4)
	await d.say(tr("ONB_B3_NO_CALL"))
	Sound.play_sfx(&"page")
	await d.quick_reach()                # 첫 장을 비워둔 채 다음 장으로 넘긴다
	await d.narrate(tr("ONB_B3_NARR_BLANK"))


# ── 4비트 · 짐 풀기 ──

## 꺼내는 순서. [사이드바 인덱스, 도구 모양, 소개 대사 키, 표정, 홍조]. 사이드바 인덱스는 NavList 순서다
const UNPACK := [
	[1, TOOL.Kind.NOTEBOOK, "ONB_B4_TODO", FACE.SOFT, false],
	[2, TOOL.Kind.CARD, "ONB_B4_HABIT", FACE.SOFT, false],
	[3, TOOL.Kind.TIMER, "ONB_B4_TIMER", FACE.SOFT, false],
	[4, TOOL.Kind.DIARY, "ONB_B4_JOURNAL", FACE.SMILE, false],
	[5, TOOL.Kind.ACORNS, "ONB_B4_RECORD", FACE.SHY, true],
]
const TODO_NAV := 1
const WRITTEN := 99                  # 선택지 대신 할 일 적기로 온 답

func _beat4() -> void:
	var d := _dialogue
	await d.wait(0.8)
	d.hide_bubble()
	d.set_face(FACE.NONE)
	d.props.book = PROPS.Book.NONE       # 수첩도 짐이다. 사이드바로 간다
	d.props.pencil = false
	await d.reveal_shell()
	# 자리를 옮긴다. 셸의 오른쪽 아래 — 사이드바와 도구 목록을 덜 가리는 곳
	await d.walk_to(d.size.x * 0.84, true)
	d.hazel.walk_dir = 1
	await d.wait(0.3)
	for i in UNPACK.size():
		var it: Array = UNPACK[i]
		await d.quick_reach()
		if i == UNPACK.size() - 1:
			d.trunk.opened = false       # 마지막 짐이다. 빈 트렁크를 닫는다
			Sound.play_sfx(&"lid")
		var r: Rect2 = _main_shell.nav_item_rect(it[0])
		await d.fly_icon(it[1], r)
		d.point_at(r)
		d.set_face(it[3], it[4])
		await d.say(tr(it[2]))
		d.unpoint()
	if _stop():
		return
	d.hide_bubble()
	d.set_face(FACE.NONE)
	await d.wait(0.4)

	# 할 일을 한 번 권한다
	d.point_at(_main_shell.nav_item_rect(TODO_NAV))
	d.set_face(FACE.SOFT)
	await d.say(tr("ONB_B4_INVITE"))
	d.unpoint()
	if _stop():
		return
	_add_sample_todo()                   # 할 일 도구가 처음 만들어지기 전에 넣는다
	_main_shell.open_tool(TODO_NAV)
	d.hide_bubble()
	# 유저가 적는 동안 말을 걸지 않는다. 적으면 선택지가 거둬진다
	var on_written := func(_title: String) -> void: d.answer_external(WRITTEN)
	Companion.todo_written.connect(on_written, CONNECT_ONE_SHOT)
	var pick := await d.choose([tr("ONB_B4_LATER")])
	if Companion.todo_written.is_connected(on_written):
		Companion.todo_written.disconnect(on_written)
	if _stop():
		return
	if pick == WRITTEN:
		await d.wait(0.9)                # 슬쩍 들여다본다
		d.set_face(FACE.SMILE)
		await d.say(tr("ONB_B4_WRITTEN"))
	else:
		d.set_face(FACE.SOFT)
		await d.say(tr("ONB_B4_LATER_RE"))


# ── 5비트 · 물러남 ──

func _beat5() -> void:
	var d := _dialogue
	await d.wait(0.8)
	d.hide_bubble()
	d.set_face(FACE.NONE)
	# 방이 다시 깔린다. 빈 트렁크를 방 구석에 놓는다 — 이 트렁크가 방의 트렁크가 된다
	await d.return_to_room()
	if _stop():
		return
	d.hazel.walk_dir = -1                        # 트렁크는 4비트에서 끌고 와 헤이즐 왼쪽 옆에 있다
	await d.wait(0.4)
	await d.walk_to(d.trunk.position.x - PUSH_GAP)   # 트렁크 뒤로 돌아간다
	var spot := d.trunk_spot_x()
	await d.walk_to(spot - HALF_SPAN - PUSH_GAP, false, true)   # 구석으로 민다. 반 뼘 모자라게
	await d.wait(0.3)
	await d.step_to(d.hazel.position.x - STEP_BACK)   # 한 걸음 물러나 본다
	await d.wait(0.7)
	await d.step_to(d.hazel.position.x + STEP_BACK)
	await d.nudge_trunk(HALF_SPAN)                    # 반 뼘 옮긴다
	await d.step_to(d.hazel.position.x - STEP_BACK)   # 다시 본다
	await d.wait(0.7)
	_main_shell.hazel_room().show_trunk = true        # 셸 상단의 방에도 이제 트렁크가 있다
	await d.narrate(tr("ONB_B5_NARR_SPOT"))
	d.hazel.walk_dir = 1
	d.set_face(FACE.SOFT)
	await d.say(tr("ONB_B5_OUTSIDE"))
	d.set_face(FACE.SMILE)
	await d.say(tr("ONB_B5_CALL_ME"))

	var labels := [tr("ONB_B5_OPT_THANKS"), tr("ONB_B5_OPT_WAVE")]
	var pick := await d.choose(labels)
	if _stop():
		return
	await _answer(labels[pick])
	if pick == 0:
		d.set_face(FACE.SHY, true)
		await d.bow()
	else:
		d.set_face(FACE.SMILE)
		await d.sway()
	await d.wait(0.4)

	# 셸 창 오른쪽 가장자리로 걸어 나간다
	d.hide_bubble()
	d.set_face(FACE.NONE)
	await d.walk_to(d.size.x + 80.0)
	if _stop():
		return
	await d.dismiss()                            # 방이 걷히면 셸 상단의 방이 드러난다. 구석에 트렁크가 있다
	# 같은 자리의 바탕화면에 내려앉아, 트렁크가 들어왔던 화면 오른쪽 아래로 간다
	var s := _desk
	var edge := Vector2i(_shell.position.x + int(d.size.x) + 24, _shell.position.y + int(d.floor_y()))
	await s.drop_in(edge)
	var usable := DisplayServer.screen_get_usable_rect(s.get_window().current_screen)
	await s.walk_window_to(usable.end.x - 140)
	await s.wait(0.5)
	await s.look_around()
	s.face_front()
	await s.wait(0.4)
	await s.write_first_day()
	await s.wait(0.6)


## 예시 할 일. 헤이즐의 말이 아니라 도구의 것이다. 다시 재생돼도 두 번 넣지 않는다
func _add_sample_todo() -> void:
	var text := tr("TODO_SAMPLE_ADD")
	var group: TodoGroup = Save.todo_groups[0]
	for t in group.tasks:
		if t.text == text:
			return
	var todo := Todo.new()
	todo.text = text
	group.tasks.append(todo)
	Save.save_todo()


## 유저가 고른 말을 띄우고 반 박자 쉰다
func _answer(text: String) -> void:
	var d := _dialogue
	d.hide_bubble()
	await d.user_says(text)
	await d.wait(0.6)
