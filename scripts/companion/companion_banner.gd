extends PanelContainer

# 컴패니언 배너 — 엔진의 판단을 화면에 옮기고, 노트 입력을 그 자리에서 받는다.
# 상태: 대기(진행 중 / 활력 축) / 완료 반응(세션·할 일·습관) / 노트 입력 / 대화.
# _held 가 참이면 화면이 붙잡힌 상태 — 대기 갱신이 갈아엎지 않는다.
# _event_id 는 노트를 달 대상만 가리킨다(습관 반응은 id가 없어 0).

signal navigate_requested(target: StringName)
signal note_pinned                      # 완료 반응의 쪽지가 꽂혔다 — 바탕화면의 헤이즐이 수첩에 적는다
signal call_requested                    # 방을 눌렀다 — 헤이즐을 부른다(docs/specs/hazel-room.md 의 "헤이즐 부르기")

const CHAR_SEC := 0.025         # 글자당 타이핑 시간
const MAX_TYPE_SEC := 0.8       # 문장 전체 상한 — 영어 긴 문장이 늘어지지 않게
const FADE_OUT_SEC := 0.3       # 완성된 문장을 거두는 시간
const FADE_OUT_SHORT_SEC := 0.08  # 아직 안 끝난 말을 거두는 시간
const OPTIONS_FADE_SEC := 0.15  # 말이 끝난 뒤 선택지가 스며드는 시간
const VOICE_EVERY := 3          # 글자마다 울리면 시끄럽다
const VOICE_MIN_GAP_MS := 60    # 상한에 걸려 빨라져도 소리가 몰리지 않게
const ROOM_SCRIPT := preload("res://scripts/room/hazel_room.gd")
const BUBBLE_W := 380.0         # 방을 가리지 않도록 쪽지를 오른쪽에 이 폭으로 붙인다
const TACK_SCRIPT := preload("res://scripts/room/note_tack.gd")
const STAMP_SIZE := 72.0        # 쪽지에 겹쳐 찍히는 도장 크기
const STAMP_OVERLAP := -22      # 쪽지와 도장 사이 간격. 음수라 도장이 쪽지 끝에 겹친다
const NOTE_PAPER := Color("#FFFDF4")
const NOTE_EDGE := Color("#D8CDB8")
const NOTE_INK := Color("#3A3128")
const NOTE_USER_INK := Color("#2C5578")

@onready var message_label: Label = $Margin/HBox/Bubble/BubbleMargin/VBox/MessageLabel
@onready var meta_label: Label = $Margin/HBox/Bubble/BubbleMargin/VBox/MetaLabel
@onready var note_edit: TextEdit = $Margin/HBox/Bubble/BubbleMargin/VBox/NoteEdit
@onready var options_box: HBoxContainer = $Margin/HBox/Bubble/BubbleMargin/VBox/OptionsBox
@onready var stamp: TextureRect = $Margin/HBox/StampSlot/StampImage
@onready var bubble: PanelContainer = $Margin/HBox/Bubble
@onready var avatar_slot: PanelContainer = $Margin/HBox/AvatarSlot
@onready var stamp_slot: Control = $Margin/HBox/StampSlot

var _event_id: int = 0          # 노트 대상 이벤트(0 = 노트 불가)
var _held := false              # 반응·대화 중 — 대기 갱신 보류
var _stamp_tween: Tween
var _type_tween: Tween
var _fade_tween: Tween
var _options_tween: Tween
var _pending_reward := false    # 이번 반응에 도장이 있는가 — 말이 끝난 뒤에 찍는다
var _pending_options: Array = []  # 퇴장 중에 스킵이 들어오면 교체를 앞당겨야 해서 들고 있는다
var _total_chars := 0           # 지금 찍는 문장의 글자 수 — 마지막 글자 판정용
var _voice_next := 0            # 다음으로 발화음을 낼 글자 인덱스
var _voice_last_ms := 0
var _said := ""                 # 지금 떠 있는 문구 줄
var _said_meta := ""            # 지금 떠 있는 보조 줄 — 둘 다 같을 때만 다시 안 찍는다
var _suspended := false         # 온보딩 동안 — 쪽지를 꽂지 않고 어떤 반응도 그리지 않는다(발화음도 안 난다)
var room: Control               # 헤이즐의 방. 온보딩이 트렁크를 놓는다

## 온보딩이 배너를 멈추고 되살린다(docs/specs/onboarding.md).
## 멈춘 동안 방은 헤이즐이 오기 전 모습이다 — 트렁크도 수첩도 없다. 쪽지는 거둔다.
## 트리에 붙기 전에도 부를 수 있다 — 붙자마자 _ready 가 첫 문구를 찍으며 소리를 내기 때문이다.
func set_suspended(on: bool) -> void:
	_suspended = on
	if not is_node_ready():
		return                  # _build_room 이 _suspended 를 보고 방을 맞춘다
	_apply_arrival()
	if on:
		_set_note_pinned(false)
		return
	_said = ""                  # 멈춰 있던 사이의 문구와 같더라도 다시 찍는다
	_said_meta = ""
	_refresh()

func _apply_arrival() -> void:
	room.show_trunk = not _suspended
	room.show_notebooks = not _suspended

func _ready() -> void:
	_build_room()
	stamp.pivot_offset = stamp.custom_minimum_size / 2.0   # 중심 기준 스케일
	stamp.modulate.a = 0.0                                 # 자리는 유지하고 안 보이게만
	# 기본값 VC_CHARS_BEFORE_SHAPING은 숨긴 글자를 줄바꿈·크기 계산에서 뺀다(TextServer.xml).
	# autowrap 라벨이라 그대로 두면 찍히는 동안 줄이 계속 다시 접혀 말풍선이 튄다.
	message_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	# 배너 전체가 클릭 대상이다(쪽지 위는 스킵, 방은 부르기). Label은 IGNORE, TextureRect는 PASS라 그대로 통과하지만
	# PanelContainer와 Control은 기본이 STOP이라 여기서 열어줘야 클릭이 배너까지 온다.
	# NoteEdit(TextEdit)은 STOP으로 둔다 — 노트를 쓰는 중에 스킵이 먹으면 안 된다.
	bubble.mouse_filter = Control.MOUSE_FILTER_PASS
	avatar_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	stamp_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_banner_input)
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

# --- 헤이즐의 방(docs/specs/hazel-room.md) ---
# 배너 뒤에 방을 깔고 아바타를 뺀다. 말풍선은 방 벽에 꽂힌 쪽지가 된다 — 헤이즐이 남기고 간 글이다.
# 씬은 고치지 않는다. 배너는 PanelContainer 라 첫 자식으로 넣으면 같은 사각형에 깔린다.
func _build_room() -> void:
	room = ROOM_SCRIPT.new()
	add_child(room)
	move_child(room, 0)                            # 쪽지 뒤에 깔린다
	_apply_arrival()
	avatar_slot.visible = false                    # 방에 헤이즐을 그리지 않는다. 몸은 바탕화면에 있다
	# 쪽지가 폭을 다 차지하면 방이 가려진다. 오른쪽에 좁게 붙이고 왼쪽을 방에 내준다
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END
	bubble.custom_minimum_size.x = BUBBLE_W
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_PASS   # 클릭이 배너까지 와야 한다(아래 _on_banner_input)
	spacer.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND   # 방은 누를 수 있다
	bubble.get_parent().add_child(spacer)
	bubble.get_parent().move_child(spacer, bubble.get_index())
	_style_note()


## 말풍선을 쪽지로 꾸민다. 종이·그림자·압정, 헤이즐의 글씨는 명조, 유저가 남기는 줄은 파란 글씨
func _style_note() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = NOTE_PAPER
	sb.border_color = NOTE_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.10)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(1, 2)
	bubble.add_theme_stylebox_override("panel", sb)
	bubble.add_child(TACK_SCRIPT.new())            # 쪽지 크기에 맞춰지고 위 가운데에 압정만 그린다
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Noto Serif KR", "Nanum Myeongjo", "Batang", "serif"])
	message_label.add_theme_font_override("font", serif)
	message_label.add_theme_color_override("font_color", NOTE_INK)
	note_edit.add_theme_color_override("font_color", NOTE_USER_INK)
	# 도장은 쪽지에 찍힌다. 작게 줄여 쪽지 오른쪽 끝에 겹쳐 둔다
	stamp_slot.custom_minimum_size = Vector2.ONE * STAMP_SIZE
	stamp_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # 칸이 쪽지 높이로 늘어나면 도장도 따라 커진다
	stamp.custom_minimum_size = Vector2.ONE * STAMP_SIZE
	# 기본 expand_mode 는 텍스처 원본 크기(120) 아래로 줄어들지 않는다. 칸에 맞춰 줄이고 비율은 지킨다
	stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bubble.get_parent().add_theme_constant_override("separation", STAMP_OVERLAP)


## 세션이 도는 동안에는 쪽지를 꽂지 않는다. 말 걸지 않는다(hazel-room.md 의 "집중 세션")
func _set_note_pinned(on: bool) -> void:
	bubble.visible = on
	if not on:
		_kill_stamp_tween()
		stamp.modulate.a = 0.0                     # 도장은 쪽지에 찍힌 것이다. 쪽지를 거두면 같이 거둔다

# --- 대기 ---
func _refresh() -> void:
	_event_id = 0                                  # 먼저 지워야 note_edit이 숨겨질 때 헛커밋이 안 남
	_held = false
	if _suspended:
		_set_note_pinned(false)                    # 온보딩 동안은 쪽지가 없다
		return
	if Clock.is_active():
		_set_note_pinned(false)                    # 진행 중엔 말 걸지 않음. 쪽지를 거두고 방의 램프만 켜진다
		_said = ""                                 # 세션이 끝나면 대기 문구를 처음부터 다시 찍는다
		_said_meta = ""
		return
	_set_note_pinned(true)
	_apply(CompanionEngine.idle(
		Companion.today_done_count(), Companion.last_activity(), Companion.habit_today()))

# 로그 적재가 완료 반응보다 먼저 온다 — ActivityLog.add()가 id를 돌려주기 전에 changed를 쏘고,
# 호출부는 그 id를 받아서야 session_logged / notify_todo_completed를 부른다.
# 즉시 갱신하면 대기 문구 연출이 먼저 시작돼 진짜 반응을 밀어낸다.
# 한 프레임 미루면 그 사이에 반응이 _held를 세우고, 미뤄진 갱신은 아래 가드에 걸려 스스로 물러난다.
func _on_activity_changed() -> void:
	_refresh_if_free.call_deferred()

func _refresh_if_free() -> void:
	if _held and not Clock.is_active():
		return                                     # 붙잡힌 상태 — 단 세션이 시작되면 조용해지는 쪽이 우선
	_refresh()

# --- 완료 반응 ---
func _on_session_logged(event_id: int) -> void:
	if _is_speaking():
		return                                     # 자동 발생 반응 — 연출 중이면 버린다(노트는 집중 목록에서 달 수 있다)
	_commit_note()                                 # 쓰던 노트가 있으면 갈아타기 전에 저장
	var e := Save.activity_log.event_by_id(event_id)
	if e.is_empty():
		return
	_event_id = event_id
	_held = true
	_apply(CompanionEngine.session_done(e))
	_notify_pinned()

func _on_todo_completed(ctx: Dictionary) -> void:
	if Clock.is_active():
		return                                     # 세션 중에는 쪽지를 꽂지 않는다
	_commit_note()
	_event_id = int(ctx.get("event_id", 0))
	_held = true
	_apply(CompanionEngine.todo_done(ctx), str(ctx.get("title", "")))   # 제목은 문장이 아니라 보조 줄로
	_notify_pinned()

func _on_habit_completed(ctx: Dictionary) -> void:
	if Clock.is_active():
		return                                     # 세션 중에는 쪽지를 꽂지 않는다
	_commit_note()
	_event_id = 0                                  # 습관은 활동 로그에 없어 노트를 달 수 없음
	_held = true
	_apply(CompanionEngine.habit_done(ctx), str(ctx.get("title", "")))
	_notify_pinned()

## 완료 반응만 알린다. 대기 문구·대화는 쪽지를 새로 꽂는 일이 아니다. 멈춘 동안(온보딩)은 꽂지 않았으니 알리지 않는다
func _notify_pinned() -> void:
	if not _suspended:
		note_pinned.emit()

func _show_note() -> void:
	_kill_type_tween()
	_kill_fade_tween()
	_said = ""                                     # 말풍선을 비웠으니 다음 문장은 처음부터 찍는다
	_said_meta = ""
	message_label.visible = false
	message_label.modulate.a = 1.0                 # 퇴장 중에 들어왔으면 흐린 채로 남는다
	meta_label.modulate.a = 1.0
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
	_reveal_options(true)                          # 노트창은 바로 조작 가능해야 한다
	note_edit.grab_focus()

# --- 엔진 반응 적용 ---
func _apply(r: Dictionary, meta: String = "") -> void:
	if _suspended:
		return                                     # 모든 반응이 여기를 지난다 — 한 곳에서 막는다
	_set_note_pinned(true)                         # 세션 완료 반응은 세션이 끝난 뒤에 온다. 거둬둔 쪽지를 다시 꽂는다
	# 보조 줄·선택지·도장은 여기서 안 건드린다 — 전부 문구와 같은 박자로 움직여야 한다.
	note_edit.visible = false
	_pending_reward = bool(r["reward"])
	_say(TranslationServer.translate(str(r["message_key"])).format(r["message_args"]), meta, r["options"])

func _build_options(options: Array) -> void:
	for c in options_box.get_children():
		options_box.remove_child(c)                # queue_free만 하면 한 프레임 동안 옛 버튼이 같이 배치됨
		c.queue_free()
	for o in options:
		var b := Button.new()
		b.theme_type_variation = &"VgActionButton"
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
			call_requested.emit()                  # 대화는 쪽지가 아니라 대화 모드에서 한다. 방을 누른 것과 같다
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

# --- 말하기 ---
# 대기 갱신(_on_activity_changed)이 자주 도는데 문구는 그대로일 때가 많다.
# 같은 문장을 매번 다시 찍으면 companion-persona.md §8의 "부산스러운 애니메이션"이 된다.
# 판정은 문구 줄과 보조 줄을 함께 본다 — 기본 완료 반응처럼 인자가 없는 문장은
# 연달아 나올 때 글자까지 같아서, 문구만 보면 새 반응인데도 아무 일도 안 일어난다.
func _say(text: String, meta: String, options: Array) -> void:
	if text == _said and meta == _said_meta:
		message_label.visible = true
		return                                     # 내용이 그대로 — 완성된 화면을 그대로 둔다
	# 퇴장은 다 한 말을 거두는 동작이다. 거둘 말이 없으면(앱 시작·노트에서 복귀) 건너뛰고,
	# 아직 안 끝난 말은 짧게만 거둔다. 안 그러면 연타할 때 거두기만 하다 끝난다.
	var fade := 0.0
	if _said != "":
		fade = FADE_OUT_SHORT_SEC if _is_speaking() else FADE_OUT_SEC
	_kill_type_tween()
	_kill_fade_tween()
	_kill_stamp_tween()                            # 도장도 같이 거둔다 — 한 알파를 두 트윈이 다투면 안 된다
	_said = text
	_said_meta = meta
	_pending_options = options
	if fade <= 0.0:
		_swap_and_type(text, meta, options)
		return
	# 거두는 중인 선택지는 흐려지는 동안에도 눌린다. 그런데 _event_id는 이미 다음 반응 것이라
	# 그 클릭은 엉뚱한 이벤트에 노트를 단다 — 보이기만 하고 안 눌리게 여기서 막는다.
	_set_options_clickable(false)
	_fade_tween = create_tween().set_parallel()
	_fade_tween.tween_property(message_label, "modulate:a", 0.0, fade)
	_fade_tween.tween_property(meta_label, "modulate:a", 0.0, fade)
	_fade_tween.tween_property(options_box, "modulate:a", 0.0, fade)
	_fade_tween.tween_property(stamp, "modulate:a", 0.0, fade)
	_fade_tween.chain().tween_callback(_swap_and_type.bind(text, meta, options))

func _swap_and_type(text: String, meta: String, options: Array) -> void:
	_swap(text, meta, options)
	_start_typing(text)

# 말풍선 내용은 한 덩어리다 — 교체 시점이 같아야 한 반응이 한 박자로 읽힌다.
func _swap(text: String, meta: String, options: Array) -> void:
	message_label.text = text
	message_label.visible = true
	message_label.modulate.a = 1.0
	message_label.visible_characters = 0
	meta_label.text = meta
	meta_label.visible = meta != ""
	meta_label.modulate.a = 1.0
	_build_options(options)
	_reveal_options(false)                         # 말이 끝나기 전엔 답을 못 고른다
	_hide_stamp()

func _start_typing(text: String) -> void:
	# get_total_character_count()는 공백·줄바꿈을 뺀 수라 visible_characters의 단위와 다르다.
	_total_chars = text.length()
	if _total_chars <= 0:
		_finish_typing()
		return
	_voice_next = 1                                # 첫 글자가 보이는 순간부터 울린다
	_type_tween = create_tween()
	_type_tween.tween_method(_set_typed, 0.0, float(_total_chars), minf(_total_chars * CHAR_SEC, MAX_TYPE_SEC))
	_type_tween.tween_callback(_finish_typing)

# --- 스킵 · 부르기 ---
# 쪽지와 도장 위는 스킵, 그 밖(방)은 부르기다. 쪽지 안의 Label·여백도 PASS 로 배너까지 올라오므로 자리로 가른다
func _on_banner_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _on_note(get_global_transform() * (event as InputEventMouseButton).position):   # gui_input 의 position 은 배너 기준이다
			_skip()
		else:
			call_requested.emit()

func _on_note(at: Vector2) -> bool:
	if not bubble.visible:
		return false                               # 세션 중엔 쪽지가 없다. 방 전체가 부르기다
	return bubble.get_global_rect().has_point(at) or stamp_slot.get_global_rect().has_point(at)

func _skip() -> void:
	if not _is_speaking():
		return                                     # 넘길 다음 문장이 없다 — 지금은 한 반응이 한 문장
	var fading := _fade_tween != null and _fade_tween.is_running()
	_kill_fade_tween()
	_kill_type_tween()
	if fading:
		_swap(_said, _said_meta, _pending_options) # 퇴장 중이었으면 교체를 앞당긴다
	_finish_typing()

# 자리는 항상 차지한 채 알파로만 감춘다 — visible을 끄면 말풍선이 리플로우된다.
# 숨은 동안엔 클릭이 버튼에 막히지 않고 배너(스킵)로 통과해야 한다.
func _reveal_options(shown: bool) -> void:
	if _options_tween != null and _options_tween.is_valid():
		_options_tween.kill()
	_options_tween = null
	_set_options_clickable(shown)
	if not shown:
		options_box.modulate.a = 0.0
		return
	if options_box.modulate.a >= 1.0:
		return
	_options_tween = create_tween()
	_options_tween.tween_property(options_box, "modulate:a", 1.0, OPTIONS_FADE_SEC)

func _set_options_clickable(clickable: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	for c in options_box.get_children():
		c.mouse_filter = filter

func _is_speaking() -> bool:
	if _fade_tween != null and _fade_tween.is_running():
		return true
	return _type_tween != null and _type_tween.is_running()

func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null

# 발화음은 글자에 붙지만 글자마다 울리지는 않는다.
# 총시간 상한에 걸려 빨라진 문장에서는 최소 간격이 자동으로 솎아낸다.
func _set_typed(v: float) -> void:
	var n := int(v)
	message_label.visible_characters = n
	if n < _voice_next or n >= _total_chars:
		return                                     # 마지막 글자엔 안 울린다 — 끝나는 순간과 겹치지 않게
	_voice_next = n + VOICE_EVERY
	var now := Time.get_ticks_msec()
	if now - _voice_last_ms < VOICE_MIN_GAP_MS:
		return
	_voice_last_ms = now
	Sound.play_voice()

# 완성 상태 = 문장이 다 보이고 + 선택지가 떠 있고 + 도장이 찍힌 상태.
# 타이핑이 끝나서 오든 스킵으로 오든 같은 자리를 통과한다.
func _finish_typing() -> void:
	message_label.visible_characters = -1          # -1 = 전부 표시
	_reveal_options(true)
	if _pending_reward:
		_pop_stamp()

func _kill_type_tween() -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = null

# --- 도장 ---
func _pop_stamp() -> void:
	_kill_stamp_tween()                            # 연속 완료 시 이전 트윈과 겹치지 않게
	stamp.scale = Vector2(0.4, 0.4)
	stamp.modulate.a = 0.0
	_stamp_tween = create_tween().set_parallel()
	_stamp_tween.tween_property(stamp, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stamp_tween.tween_property(stamp, "modulate:a", 1.0, 0.25)

func _hide_stamp() -> void:
	_kill_stamp_tween()
	stamp.modulate.a = 0.0
	stamp.scale = Vector2.ONE

func _kill_stamp_tween() -> void:
	if _stamp_tween != null and _stamp_tween.is_valid():
		_stamp_tween.kill()
	_stamp_tween = null
