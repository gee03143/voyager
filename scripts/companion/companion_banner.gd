extends PanelContainer

# 컴패니언 배너 — 엔진의 판단을 화면에 옮기고, 노트 입력을 그 자리에서 받는다.
# 상태: 대기(진행 중 / 활력 축) / 완료 반응(세션·할 일·습관) / 노트 입력 / 대화.
# _held 가 참이면 화면이 붙잡힌 상태 — 대기 갱신이 갈아엎지 않는다.
# _event_id 는 노트를 달 대상만 가리킨다(습관 반응은 id가 없어 0).

signal navigate_requested(target: StringName)

@onready var message_label: Label = $Margin/HBox/Bubble/BubbleMargin/VBox/MessageLabel
@onready var meta_label: Label = $Margin/HBox/Bubble/BubbleMargin/VBox/MetaLabel
@onready var note_edit: TextEdit = $Margin/HBox/Bubble/BubbleMargin/VBox/NoteEdit
@onready var options_box: HBoxContainer = $Margin/HBox/Bubble/BubbleMargin/VBox/OptionsBox
@onready var stamp: TextureRect = $Margin/HBox/StampSlot/StampImage

var _event_id: int = 0          # 노트 대상 이벤트(0 = 노트 불가)
var _held := false              # 반응·대화 중 — 대기 갱신 보류
var _stamp_tween: Tween

func _ready() -> void:
	stamp.pivot_offset = stamp.custom_minimum_size / 2.0   # 중심 기준 스케일
	stamp.modulate.a = 0.0                                 # 자리는 유지하고 안 보이게만
	note_edit.placeholder_text = TranslationServer.translate("COMPANION_NOTE_PLACEHOLDER")
	note_edit.focus_exited.connect(_commit_note)
	note_edit.gui_input.connect(_on_note_gui_input)
	Clock.session_logged.connect(_on_session_logged)
	Companion.todo_completed.connect(_on_todo_completed)
	Companion.habit_completed.connect(_on_habit_completed)
	Save.activity_log.changed.connect(_on_activity_changed)
	Clock.pomodoro.running_changed.connect(_on_activity_changed)
	Clock.timer.running_changed.connect(_on_activity_changed)
	_refresh()

# --- 대기 ---
func _refresh() -> void:
	_event_id = 0                                  # 먼저 지워야 note_edit이 숨겨질 때 헛커밋이 안 남
	_held = false
	if Clock.is_active():
		_apply(CompanionEngine.focusing())         # 진행 중엔 말 걸지 않음
		return
	_apply(CompanionEngine.idle(
		Companion.today_done_count(), Companion.last_activity(), Companion.habit_today()))

func _on_activity_changed() -> void:
	if _held and not Clock.is_active():
		return                                     # 붙잡힌 상태 — 단 세션이 시작되면 조용해지는 쪽이 우선
	_refresh()

# --- 완료 반응 ---
func _on_session_logged(event_id: int) -> void:
	_commit_note()                                 # 쓰던 노트가 있으면 갈아타기 전에 저장
	var e := Save.activity_log.event_by_id(event_id)
	if e.is_empty():
		return
	_event_id = event_id
	_held = true
	_apply(CompanionEngine.session_done(e))

func _on_todo_completed(ctx: Dictionary) -> void:
	_commit_note()
	_event_id = int(ctx.get("event_id", 0))
	_held = true
	_apply(CompanionEngine.todo_done(ctx), str(ctx.get("title", "")))   # 제목은 문장이 아니라 보조 줄로

func _on_habit_completed(ctx: Dictionary) -> void:
	_commit_note()
	_event_id = 0                                  # 습관은 활동 로그에 없어 노트를 달 수 없음
	_held = true
	_apply(CompanionEngine.habit_done(ctx), str(ctx.get("title", "")))

func _show_note() -> void:
	message_label.visible = false
	var e := Save.activity_log.event_by_id(_event_id)
	var label := ActivityFormat.session_label(e)
	if label == "":
		label = str(e.get("title", ""))            # 세션이 아닌 이벤트(할 일 등)
	meta_label.text = label
	meta_label.visible = true
	note_edit.visible = true
	note_edit.text = Save.activity_log.note_of(_event_id)
	# 저장 = 커밋 후 대기로 — DISMISS와 하는 일이 같다
	_build_options([{"key": "COMPANION_NOTE_SAVE", "action": CompanionEngine.Action.DISMISS}])
	note_edit.grab_focus()

# --- 엔진 반응 적용 ---
func _apply(r: Dictionary, meta: String = "") -> void:
	message_label.text = TranslationServer.translate(str(r["message_key"])).format(r["message_args"])
	message_label.visible = true
	meta_label.text = meta
	meta_label.visible = meta != ""
	note_edit.visible = false
	_build_options(r["options"])
	if bool(r["reward"]):
		_pop_stamp()
	else:
		_hide_stamp()

func _build_options(options: Array) -> void:
	for c in options_box.get_children():
		options_box.remove_child(c)                # queue_free만 하면 한 프레임 동안 옛 버튼이 같이 배치됨
		c.queue_free()
	for o in options:
		var b := Button.new()
		b.text = TranslationServer.translate(str(o["key"]))
		var action := int(o["action"])
		var arg: StringName = o.get("arg", &"")    # 대화 노드 id (없으면 빈 값)
		b.pressed.connect(func(): _on_action(action, arg))
		options_box.add_child(b)

func _on_action(action: int, arg: StringName = &"") -> void:
	match action:
		CompanionEngine.Action.NOTE:
			_show_note()
		CompanionEngine.Action.DISMISS:
			_commit_note()
			_refresh()
		CompanionEngine.Action.TALK:
			_held = true
			_apply(CompanionEngine.talk_open(Companion.today_done_count(), Companion.is_first_time()))
		CompanionEngine.Action.TALK_NODE:
			_apply(CompanionEngine.talk_node(arg, Companion.habit_today()))
		CompanionEngine.Action.GOTO_TODO:
			_goto(&"todo")
		CompanionEngine.Action.GOTO_TIMER:
			_goto(&"timer")
		CompanionEngine.Action.GOTO_RECORD:
			_goto(&"record")
		CompanionEngine.Action.GOTO_JOURNAL:
			_goto(&"journal")
		CompanionEngine.Action.GOTO_HABIT:
			_goto(&"habit")

func _goto(target: StringName) -> void:
	navigate_requested.emit(target)
	_refresh()                                     # 안내까지 했으면 대화는 끝 — 배너는 평소 상태로

# --- 노트 ---
func _commit_note() -> void:
	if _event_id == 0 or not note_edit.visible:
		return
	Save.activity_log.set_note(_event_id, note_edit.text)

func _on_note_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		if event.shift_pressed:
			note_edit.insert_text_at_caret("\n")
		else:
			_on_action(CompanionEngine.Action.DISMISS)

# --- 도장 ---
func _pop_stamp() -> void:
	if _stamp_tween != null and _stamp_tween.is_valid():
		_stamp_tween.kill()                        # 연속 완료 시 이전 트윈과 겹치지 않게
	stamp.scale = Vector2(0.4, 0.4)
	stamp.modulate.a = 0.0
	_stamp_tween = create_tween().set_parallel()
	_stamp_tween.tween_property(stamp, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stamp_tween.tween_property(stamp, "modulate:a", 1.0, 0.25)

func _hide_stamp() -> void:
	if _stamp_tween != null and _stamp_tween.is_valid():
		_stamp_tween.kill()
	stamp.modulate.a = 0.0
	stamp.scale = Vector2.ONE
