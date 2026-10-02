extends Control

## 셸 창의 대화 모드. MainShell 의 형제로 붙어 사이드바와 배너까지 덮고 창 전체를 쓴다.
## MainShell 은 이 노드를 모른다(docs/specs/onboarding.md 의 "셸").
##
## 여기는 무대와 연출 부품만 갖는다. 무엇을 어떤 순서로 말할지는 재생기가 정한다 —
## 온보딩(onboarding_player.gd)과 헤이즐 부르기(scripts/room/hazel_call.gd) 둘이다.
## 연출 부품은 전부 코루틴이다 — 재생기가 await 로 줄을 세운다.
##
## 중단(abort)되면 모든 부품이 기다리지 않고 바로 돌아온다. 선택지·입력은 "답 없음"을 돌려준다.
## 재생기는 답을 받은 직후마다 aborted 를 보고 멈춘다(docs/specs/onboarding.md 의 "중단의 흐름").

signal _answered(value: Variant)

const VIEW_SCRIPT := preload("res://scripts/companion/shimeji_view.gd")
const BUBBLE_SCRIPT := preload("res://scripts/onboarding/onboarding_bubble.gd")
const MARKS_SCRIPT := preload("res://scripts/onboarding/face_marks.gd")
const PROPS_SCRIPT := preload("res://scripts/onboarding/hazel_props.gd")
const TRUNK_SCRIPT := preload("res://scripts/onboarding/trunk.gd")
const ICON_SCRIPT := preload("res://scripts/onboarding/tool_icon.gd")
const ROOM_SCRIPT := preload("res://scripts/room/hazel_room.gd")

const HAZEL_SCALE := 1.6
const HAZEL_HEIGHT := 160.0          # 리그 계약상 키(docs/architecture/companion-rig.md)
const HAZEL_AT := 0.34               # 헤이즐이 서는 자리. 창 폭 비율
const TRUNK_AT := 0.16
const TRUNK_RATIO := 0.95            # 헤이즐 배율 대비. 자기 몸만 하다
const FLOOR_RATIO := 0.8

# 초안값. F6 에서 눈으로 조정한다
const TYPE_SEC := 0.035              # 말풍선 글자당
const DWELL_MIN := 0.9               # 다 찍힌 뒤 머무는 시간
const DWELL_PER_CHAR := 0.045
const USER_HOLD := 1.4               # 유저의 말이 떠 있는 시간
const NARR_HOLD := 2.0
const RISE := 14.0                   # 조금 아래에서 스며들며 제자리로 온다
const RISE_SEC := 0.35
const FADE_SEC := 0.25
const DISMISS_SEC := 0.4
const REVEAL_SEC := 0.6               # 4비트에서 바탕이 걷히는 시간
const WALK_SPEED := 170.0             # 화면 픽셀/초. 리그 걸음 주기보다 빨라 발이 조금 미끄러진다
const POINT_DEG := 78.0               # 가리키는 왼팔 각도
const FLY_SEC := 0.55
const ITALIC_SLANT := 0.2

const C_PAPER := Color("#FCFAF6")
const C_LINE := Color("#2A2320")
const C_TX := Color("#221F1A")
const C_LINK := Color("#2C5578")
const C_MUTED := Color("#6B5E50")

var hazel: VIEW_SCRIPT
var props: PROPS_SCRIPT
var trunk: TRUNK_SCRIPT
var room: ROOM_SCRIPT                 # 배경. 셸 상단의 그 방을 창 크기로 확대한 것이다(docs/specs/hazel-room.md)
var aborted := false

var _marks: MARKS_SCRIPT
var _bubble: BUBBLE_SCRIPT
var _bg: Control                      # = room. 4비트에서 걷히고 5비트에서 다시 깔린다
var _floor: ColorRect
var _ring: Panel                      # 가리키는 사이드바 항목을 두르는 테
var _dragging := false                # 트렁크를 끌며 걷는 중
var _drag_rel := 0.0                  # 끌거나 미는 동안 헤이즐 기준 트렁크의 x
var _placed := false                  # 헤이즐·트렁크가 기본 자리를 떠났다 — 창 크기가 바뀌어도 되돌리지 않는다
var _user_box: PanelContainer
var _user_label: Label
var _narr: Label
var _choice_panel: PanelContainer
var _choices: VBoxContainer
var _skip := false
var _pending: Variant = null          # 기다리기 전에 도착한 답. 신호만 쏘면 받을 쪽이 없을 때 사라진다


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP     # 대화 모드 동안 뒤의 도구를 누를 수 없다
	var serif_italic := _serif_italic()

	room = ROOM_SCRIPT.new()
	room.fill = true
	room.floor_ratio = FLOOR_RATIO                # 헤이즐이 방 바닥에 선다
	add_child(room)                               # _ready 가 클릭을 IGNORE 로 둔다
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = room
	_floor = ColorRect.new()
	_floor.color = Color(C_LINE, 0.35)
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor.visible = false                        # 바닥은 방이 그린다. 걷기 기준선으로만 남긴다
	add_child(_floor)

	# 헤이즐을 트렁크보다 먼저 붙인다. 트렁크 뒤로 지나가면 가려진다
	hazel = VIEW_SCRIPT.new()
	hazel.scale = Vector2.ONE * HAZEL_SCALE
	add_child(hazel)
	props = PROPS_SCRIPT.new()
	hazel.add_child(props)                        # 리그 위에 얹는다
	_marks = MARKS_SCRIPT.new()
	hazel.add_child(_marks)
	trunk = TRUNK_SCRIPT.new()
	trunk.scale = Vector2.ONE * HAZEL_SCALE * TRUNK_RATIO
	add_child(trunk)
	# 헤이즐은 아직 바탕화면에 있다. 들어오는 순간(enter_from_left)까지 방에 보이지 않는다 —
	# 셸이 열리자마자 서 있으면 바탕화면의 헤이즐과 둘이 된다(2026-10-01 유저 보고)
	hazel.visible = false
	trunk.visible = false

	_ring = Panel.new()
	var rs := StyleBoxFlat.new()
	rs.draw_center = false
	rs.border_color = Color("#C88A4A")
	rs.set_border_width_all(3)
	rs.set_corner_radius_all(8)
	_ring.add_theme_stylebox_override("panel", rs)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.visible = false
	add_child(_ring)

	_bubble = BUBBLE_SCRIPT.new()
	add_child(_bubble)

	_narr = Label.new()
	_narr.add_theme_font_override("font", serif_italic)
	_narr.add_theme_font_size_override("font_size", 22)
	_narr.add_theme_color_override("font_color", C_MUTED)
	_narr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narr.visible = false
	add_child(_narr)

	_user_box = PanelContainer.new()
	var us := StyleBoxFlat.new()
	us.bg_color = Color(1, 1, 1, 0.94)
	us.set_corner_radius_all(10)
	us.set_content_margin_all(12)
	us.content_margin_left = 20
	us.content_margin_right = 20
	us.border_color = C_LINK
	us.set_border_width_all(2)
	_user_box.add_theme_stylebox_override("panel", us)
	_user_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_user_label = Label.new()
	_user_label.add_theme_color_override("font_color", C_LINK)
	_user_label.add_theme_font_size_override("font_size", 22)
	_user_box.add_child(_user_label)
	_user_box.visible = false
	add_child(_user_box)

	# 선택지는 유저의 대사다. 오른쪽 아래 판에 담는다
	_choice_panel = PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(C_PAPER, 0.97)
	cs.set_corner_radius_all(12)
	cs.set_content_margin_all(10)
	cs.border_color = C_LINE
	cs.set_border_width_all(2)
	_choice_panel.add_theme_stylebox_override("panel", cs)
	_choices = VBoxContainer.new()
	_choice_panel.add_child(_choices)
	_choice_panel.visible = false
	add_child(_choice_panel)

	resized.connect(_layout)
	_layout()


## 한글 명조에 이탤릭 면이 없어 기울여서 흉내 낸다. 형태는 FontVariation 클래스 문서의 예시를 따랐다
func _serif_italic() -> FontVariation:
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Noto Serif KR", "Nanum Myeongjo", "Batang", "serif"])
	var v := FontVariation.new()
	v.base_font = serif
	v.variation_transform = Transform2D(Vector2(1.0, ITALIC_SLANT), Vector2(0.0, 1.0), Vector2.ZERO)
	return v


func _layout() -> void:
	var fy := floor_y()
	_floor.position = Vector2(0, fy)
	_floor.size = Vector2(size.x, 2)
	if _placed:
		return
	hazel.position = Vector2(size.x * HAZEL_AT, fy)
	trunk.position = Vector2(size.x * TRUNK_AT, fy)


func floor_y() -> float:
	return size.y * FLOOR_RATIO


func _process(_delta: float) -> void:
	if _dragging:
		trunk.position.x = hazel.position.x + _drag_rel
	if _bubble.visible:
		_place_bubble()


func _drag_offset() -> float:
	return 44.0 * HAZEL_SCALE + TRUNK_SCRIPT.W * 0.5 * HAZEL_SCALE * TRUNK_RATIO + 4.0


## 누르면 타이핑 중인 말은 즉시 완성, 다 찍힌 말은 머무는 시간을 건너뛴다
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_skip = true


## 셸이 닫혔다. 기다리던 것을 전부 풀어준다
func abort() -> void:
	aborted = true
	_skip = true
	_answered.emit(null)                         # 중단은 _wait_answer 가 aborted 로도 본다


# ── 기다림 ──

func wait(t: float) -> void:
	if aborted:
		return
	await get_tree().create_timer(t).timeout


## 누르면 건너뛰는 기다림
func hold(t: float) -> void:
	_skip = false
	while t > 0.0 and not _skip and not aborted:
		t -= get_process_delta_time()
		await get_tree().process_frame
	_skip = false


# ── 헤이즐 ──

## 표정. 홍조·땀방울은 리그에 없어 여기서 얹는다(docs/companion-persona.md §8)
func set_face(f: int, blush := false, sweat := false) -> void:
	hazel.face = f
	_marks.blush = blush
	_marks.sweat = sweat


## 머리 위 말풍선에 지금 하는 말 하나만 띄운다.
## close 가 거짓이면 다음 말이 올 때까지 말풍선을 남긴다. speaker 를 주면 이름표를 바꾼다
func say(text: String, close := false, speaker := "") -> void:
	if aborted:
		return
	if speaker != "":
		_bubble.set_speaker(speaker)
	_bubble.set_text(text)
	_place_bubble()
	_bubble.visible = true
	_skip = false
	var shown := 0.0
	while shown < text.length() and not _skip:
		shown += get_process_delta_time() / TYPE_SEC
		_bubble.label.visible_characters = int(shown)
		await get_tree().process_frame
	_bubble.label.visible_characters = -1
	await hold(DWELL_MIN + text.length() * DWELL_PER_CHAR)
	if close:
		_bubble.visible = false


func hide_bubble() -> void:
	_bubble.visible = false


## 이름표가 뒤집히며 이름이 드러난다
func flip_name(speaker: String) -> void:
	if aborted:
		return
	var tag: Control = _bubble.tag
	var tw := create_tween()
	tw.tween_property(tag, "scale:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_bubble.set_speaker(speaker)
	var back := create_tween()
	back.tween_property(tag, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished


## 인사. 리그에 인사 동작이 없어 몸을 눌렀다 펴는 것으로 대신한다
func bow() -> void:
	if aborted:
		return
	var s := HAZEL_SCALE
	Sound.play_sfx(&"cloth")
	var tw := create_tween()
	tw.tween_property(hazel, "scale", Vector2(s * 1.03, s * 0.84), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(hazel, "scale", Vector2(s, s), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## 트렁크에 손을 넣었다 빼는 것 같은 짧은 동작. 몸을 짧게 눌렀다 편다
func quick_reach() -> void:
	if aborted:
		return
	var s := HAZEL_SCALE
	var tw := create_tween()
	tw.tween_property(hazel, "scale", Vector2(s * 1.02, s * 0.92), 0.09)
	tw.tween_property(hazel, "scale", Vector2(s, s), 0.11)
	await tw.finished


## x 까지 걷는다. drag 면 트렁크를 뒤에 끌고, push 면 앞에 놓인 트렁크를 지금 간격 그대로 민다.
## 걷고 나면 보던 쪽을 유지한다
func walk_to(x: float, drag := false, push := false) -> void:
	if aborted:
		return
	_placed = true
	var dir := 1 if x > hazel.position.x else -1
	_dragging = drag or push
	_drag_rel = trunk.position.x - hazel.position.x if push else -dir * _drag_offset()
	var snd := Sound.play_sfx(&"drag") if _dragging else null
	hazel.start_act(VIEW_SCRIPT.Act.WALK)
	hazel.walk_dir = dir
	while (x - hazel.position.x) * dir > 0.0 and not aborted:
		hazel.position.x += dir * WALK_SPEED * get_process_delta_time()
		await get_tree().process_frame
	hazel.position.x = x
	_dragging = false
	Sound.stop_sfx(snd)
	hazel.stop_act()
	hazel.walk_dir = dir                          # stop_act 가 방향을 되돌리므로 보던 쪽을 유지한다


## 창 왼쪽 가장자리 밖에서 x 까지 들어온다. 온보딩 1비트는 트렁크를 끌고, 헤이즐 부르기는 빈손이다
func enter_from_left(x: float, with_trunk := true) -> void:
	_placed = true
	hazel.position = Vector2(-80, floor_y())
	trunk.position = Vector2(-80 - _drag_offset(), floor_y())
	hazel.visible = true
	trunk.visible = with_trunk
	await walk_to(x, with_trunk)


## 이미 방 안에 있던 헤이즐을 x 에 세운다. 걸어 들어오지 않는다(바탕화면에서 내보낸 동안의 부르기)
func place_at(x: float) -> void:
	_placed = true
	hazel.position = Vector2(x, floor_y())
	hazel.visible = true
	trunk.visible = false


## 창 왼쪽 가장자리 밖으로 걸어 나간다(헤이즐 부르기의 끝)
func exit_left() -> void:
	_bubble.visible = false
	await walk_to(-80)
	hazel.visible = false


## 문턱에서 발을 턴다. 왼발, 오른발, 다시 왼발
func wipe_feet() -> void:
	if aborted:
		return
	var base := hazel.position.x
	for dx in [-10.0, 10.0, -10.0]:
		Sound.play_sfx(&"step")
		var tw := create_tween()
		tw.tween_property(hazel, "position:x", base + dx, 0.12)
		tw.tween_property(hazel, "position:x", base, 0.12)
		await tw.finished
		await wait(0.12)


## 끌고 온 트렁크를 제자리에 반듯이 세운다
func straighten_trunk() -> void:
	if aborted:
		return
	Sound.play_sfx(&"drag_short")
	var tw := create_tween()
	tw.tween_property(trunk, "position:x", size.x * TRUNK_AT, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## 보는 쪽을 바꾸지 않고 x 까지 옮겨 선다. 한 걸음 물러나 보거나 다가설 때 쓴다
func step_to(x: float) -> void:
	if aborted:
		return
	_placed = true
	var tw := create_tween()
	tw.tween_property(hazel, "position:x", x, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## 트렁크를 손으로 dx 만큼 옮긴다. 짧게 손을 뻗고 트렁크가 미끄러진다
func nudge_trunk(dx: float) -> void:
	if aborted:
		return
	await quick_reach()
	Sound.play_sfx(&"drag_short")
	var tw := create_tween()
	tw.tween_property(trunk, "position:x", trunk.position.x + dx, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


## 방에서 트렁크가 놓이는 자리. 방이 그리는 트렁크 가운데다
func trunk_spot_x() -> float:
	return room.trunk_center_x()


## 좌우로 몸을 흔든다. 손 흔들기 동작이 리그에 없어 대신한다
func sway() -> void:
	if aborted:
		return
	var tw := create_tween()
	for i in 3:
		tw.tween_property(hazel, "rotation_degrees", 6.0, 0.12)
		tw.tween_property(hazel, "rotation_degrees", -6.0, 0.12)
	tw.tween_property(hazel, "rotation_degrees", 0.0, 0.1)
	await tw.finished


## 작게 한 번 뛴다. 꼬리를 크게 움직이는 동작이 리그에 없어 대신한다
func hop() -> void:
	if aborted:
		return
	var y := hazel.position.y
	var tw := create_tween()
	tw.tween_property(hazel, "position:y", y - 14.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hazel, "position:y", y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


# ── 헤이즐 밖의 줄 ──

## 유저의 말(고른 선택지). 발밑에 조용히 떠올랐다 사라진다
func user_says(text: String) -> void:
	if aborted:
		return
	_user_label.text = text
	await _rise(_user_box, size * Vector2(0.5, 0.9))
	await hold(USER_HOLD)
	await _fade_out(_user_box)


## 내레이터. 화면 위쪽에 작게 덧붙인다
func narrate(text: String) -> void:
	if aborted:
		return
	_narr.text = text
	await _rise(_narr, size * Vector2(0.5, 0.1))
	await hold(NARR_HOLD)
	await _fade_out(_narr)


# ── 4비트: 셸 위에서 ──

## 대화 모드의 바탕이 걷히고 셸이 드러난다. 헤이즐과 트렁크는 셸 위에 남는다.
## 이때부터 뒤의 도구를 누를 수 있다 — 유저가 할 일 도구에 직접 적어야 한다
func reveal_shell() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 바탕이 걷히면 내레이터가 셸 글자 위에 겹친다. 바탕화면 무대처럼 종이를 받친다
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color(C_PAPER, 0.94)
	ns.set_corner_radius_all(8)
	ns.content_margin_top = 8
	ns.content_margin_bottom = 8
	ns.content_margin_left = 16
	ns.content_margin_right = 16
	_narr.add_theme_stylebox_override("normal", ns)
	if aborted:
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(_bg, "modulate:a", 0.0, REVEAL_SEC)
	tw.tween_property(_floor, "modulate:a", 0.0, REVEAL_SEC)
	await tw.finished


## 걷혔던 방이 다시 깔린다(5비트). 뒤의 셸은 다시 누를 수 없다
func return_to_room() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if aborted:
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(_bg, "modulate:a", 1.0, REVEAL_SEC)
	tw.tween_property(_floor, "modulate:a", 1.0, REVEAL_SEC)
	await tw.finished


## 트렁크에서 도구 하나를 꺼내 셸 사이드바 항목(rect, 창 캔버스 좌표)으로 날려 보낸다
func fly_icon(kind: int, to: Rect2) -> void:
	if aborted:
		return
	var icon := ICON_SCRIPT.new()
	icon.kind = kind
	add_child(icon)
	var from := trunk.position + Vector2(0, -TRUNK_SCRIPT.H * trunk.scale.y - 30) - icon.size * 0.5
	icon.position = from
	var dest := Vector2(to.position.x + 6, to.get_center().y - icon.size.y * 0.5)
	Sound.play_sfx(&"pluck")
	var tw := create_tween().set_parallel()
	tw.tween_property(icon, "position", dest, FLY_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(icon, "scale", Vector2.ONE * 0.7, FLY_SEC)
	await tw.finished
	var fade := create_tween()
	fade.tween_property(icon, "modulate:a", 0.0, 0.2)
	await fade.finished
	remove_child(icon)
	icon.queue_free()


## 사이드바 항목을 가리킨다. 왼팔을 들고 항목에 테를 두른다
func point_at(r: Rect2) -> void:
	_ring.position = r.position - Vector2(4, 4)
	_ring.size = r.size + Vector2(8, 8)
	_ring.visible = true
	_ring.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_ring, "modulate:a", 1.0, 0.2)
	tw.tween_property(hazel, "point_l", POINT_DEG, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func unpoint() -> void:
	_ring.visible = false
	var tw := create_tween()
	tw.tween_property(hazel, "point_l", 0.0, 0.2)


## 재생기가 선택지 밖의 사건(할 일 적기)으로 답을 대신 줄 때 쓴다
func answer_external(v: Variant) -> void:
	_answer(v)


## 답은 항상 여기를 거친다. 받아둔 뒤 신호를 쏜다
func _answer(v: Variant) -> void:
	_pending = v
	_answered.emit(v)


# ── 답을 받는 것 ──

## 선택지를 띄우고 고른 번호를 돌려준다. 중단되면 -1
func choose(labels: Array) -> int:
	if aborted:
		return -1
	_pending = null
	_clear_choices()
	for i in labels.size():
		var b := _choice_button(labels[i])
		b.pressed.connect(_answer.bind(i))
		_choices.add_child(b)
	await _place_choices()
	var v: Variant = await _wait_answer()
	_clear_choices()
	return -1 if v == null else int(v)


## 이름 입력 칸. 적은 이름을 돌려준다. 비워두거나 나중에를 골라도, 중단돼도 빈 문자열이다 —
## 셋을 가르는 것은 재생기가 aborted 로 한다
func ask_name(placeholder: String, tell_label: String, later_label: String, prefill := "", max_len := 12) -> String:
	if aborted:
		return ""
	_pending = null
	_clear_choices()
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.max_length = max_len
	edit.text = prefill                          # 다시 받을 때 앞서 적은 이름을 고치기만 하면 되게
	edit.caret_column = prefill.length()
	edit.custom_minimum_size = Vector2(240, 0)
	edit.add_theme_font_size_override("font_size", 20)
	_choices.add_child(edit)
	var tell := _choice_button(tell_label)
	var later := _choice_button(later_label)
	# 버튼이 포커스를 가져가지 않게 한다. Windows 는 조합 중 클릭이 확정 문자보다 먼저 배달되므로(ime_commit_guard.gd),
	# 버튼이 포커스를 가져가면 마지막 글자가 입력 칸이 아닌 곳에 떨어져 사라진다
	tell.focus_mode = Control.FOCUS_NONE
	later.focus_mode = Control.FOCUS_NONE
	_choices.add_child(tell)
	_choices.add_child(later)
	tell.pressed.connect(func() -> void: _answer(edit.text))
	edit.text_submitted.connect(func(t: String) -> void: _answer(t))
	later.pressed.connect(_answer.bind(""))
	await _place_choices()
	edit.grab_focus()
	var v: Variant = await _wait_answer()
	_clear_choices()
	return "" if v == null else str(v).strip_edges()


## 답을 기다린다. 판을 띄우는 한 프레임 사이에 중단되면 abort 의 신호는 받을 쪽 없이 지나가 버린다 —
## 그래서 기다리기 직전에 한 번 더 본다
func _wait_answer() -> Variant:
	if aborted:
		return null
	if _pending != null:
		var v: Variant = _pending
		_pending = null
		return v
	var got: Variant = await _answered
	_pending = null
	return got


func _choice_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.flat = true
	b.add_theme_color_override("font_color", C_LINK)
	return b


func _place_choices() -> void:
	_choice_panel.visible = true
	await get_tree().process_frame
	var p := _choice_panel
	p.size = p.get_combined_minimum_size()
	if hazel.position.x > size.x * 0.6:
		# 헤이즐이 오른쪽에 있으면(4비트) 헤이즐 왼쪽 옆, 바닥 높이에 둔다. 오른쪽 아래는 헤이즐이 차지한다
		p.position = Vector2(hazel.position.x - 90.0 * HAZEL_SCALE - p.size.x, floor_y() - p.size.y)
	else:
		p.position = Vector2(size.x - p.size.x - 30, size.y - p.size.y - 20)


func _clear_choices() -> void:
	_choice_panel.visible = false
	for c in _choices.get_children():
		_choices.remove_child(c)         # 같은 프레임에 트리에서 빼고 지운다(docs/architecture/list-rebuild.md)
		c.queue_free()


# ── 걷기 ──

## 대화 모드를 걷는다. 걷히면 뒤의 셸이 드러난다
func dismiss() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 걷힌 뒤에도 남아 있으면 뒤의 셸을 막는다
	_bubble.visible = false
	_clear_choices()
	if aborted:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, DISMISS_SEC)
	await tw.finished


# ── 내부 ──

## 조금 아래에서 스며들며 제자리로 온다. at 은 중심 자리
func _rise(c: Control, at: Vector2) -> void:
	c.visible = true
	c.modulate.a = 0.0
	await get_tree().process_frame
	c.size = c.get_combined_minimum_size()
	var target := at - c.size * 0.5
	c.position = target + Vector2(0, RISE)
	var tw := create_tween().set_parallel()
	tw.tween_property(c, "modulate:a", 1.0, RISE_SEC)
	tw.tween_property(c, "position", target, RISE_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


func _fade_out(c: CanvasItem) -> void:
	if not c.visible:
		return
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 0.0, FADE_SEC)
	await tw.finished
	c.visible = false


func _place_bubble() -> void:
	var top := hazel.position.y - HAZEL_HEIGHT * HAZEL_SCALE - 24
	var bx := clampf(hazel.position.x - _bubble.size.x * 0.5, 16, size.x - _bubble.size.x - 16)
	_bubble.position = Vector2(bx, top - _bubble.size.y)
	_bubble.tail_x = hazel.position.x - bx
	_bubble.queue_redraw()
