extends Node2D

## 바탕화면 무대. 온보딩 동안 시메지 창을 넓혀 트렁크·말풍선·선택지를 함께 그린다(docs/specs/onboarding.md 의 "바탕화면 무대").
## 시메지 루트의 자식이고, 루트의 창과 헤이즐(ShimejiView)을 넘겨받아 움직인다.
##
## 무엇을 어떤 순서로 보여줄지는 재생기가 정한다. 여기는 무대와 연출 부품만 갖는다 — 대화 모드(dialogue_mode.gd)와 같은 짜임이다.
## 투명 창이라 그려진 픽셀만 클릭을 받는다. 선택지 버튼과 헤이즐 몸이 클릭을 받는다.
##
## 두 번 쓰인다.
## - 1비트 앞부분: 창을 STAGE_SIZE 로 넓혀 화면 오른쪽 아래에 둔다. 트렁크가 창 오른쪽 가장자리(= 화면 가장자리)에서 들어온다
## - 5비트 뒷부분: 시메지 크기 창으로 셸 가장자리에서 내려앉아 제자리로 걸어간다

signal _answered(value: Variant)

const BUBBLE_SCRIPT := preload("res://scripts/onboarding/onboarding_bubble.gd")
const TRUNK_SCRIPT := preload("res://scripts/onboarding/trunk.gd")
const PROPS_SCRIPT := preload("res://scripts/onboarding/hazel_props.gd")
const VIEW_SCRIPT := preload("res://scripts/companion/shimeji_view.gd")

const STAGE_SIZE := Vector2i(720, 440)
const HIDDEN_SIZE := Vector2i(2, 2)  # 헤이즐이 셸 안에 있는 동안의 창 크기. 실제로는 OS 최소(64×64)까지만 준다
const HIDDEN_POS := Vector2i(-20000, -20000)   # 모든 모니터 밖
const HAZEL_HEIGHT := 160.0          # 리그 계약상 키. 바탕화면에서는 시메지 배율(1) 그대로다
const TRUNK_RATIO := 0.95
const WALK_SPEED := 110.0            # 바탕화면 걷기. 시메지 평소(46)보다 빠르다 — 연출이 늘어지지 않게
const TYPE_SEC := 0.035
const DWELL_MIN := 0.9
const DWELL_PER_CHAR := 0.045
const RISE := 12.0
const RISE_SEC := 0.35
const FADE_SEC := 0.25
const ITALIC_SLANT := 0.2
const GRAVITY := 2000.0

const C_PAPER := Color("#FCFAF6")
const C_LINE := Color("#2A2320")
const C_TX := Color("#221F1A")
const C_LINK := Color("#2C5578")
const C_MUTED := Color("#6B5E50")

var trunk: TRUNK_SCRIPT
var props: PROPS_SCRIPT
var click_opens := false             # 참이면 헤이즐을 누르는 것이 선택지 0번(열어준다)과 같다

var _view: VIEW_SCRIPT
var _win_size: Vector2i              # 시메지 평소 창 크기
var _foot_margin := 40               # 창 아래에서 발바닥까지
var _bubble: BUBBLE_SCRIPT
var _narr: PanelContainer
var _narr_label: Label
var _user_box: PanelContainer
var _user_label: Label
var _card: PanelContainer
var _card_label: Label
var _choice_panel: PanelContainer
var _choices: VBoxContainer
var _dragging := false
var _drag_dir := 1
var _pending: Variant = null          # 기다리기 전에 도착한 답. 신호만 쏘면 받을 쪽이 없을 때 사라진다


## view 는 루트의 헤이즐, win_size·foot_margin 은 루트의 평소 창 규격이다
func setup(view: VIEW_SCRIPT, win_size: Vector2i, foot_margin: int) -> void:
	_view = view
	_win_size = win_size
	_foot_margin = foot_margin


func _ready() -> void:
	var serif_italic := _serif_italic()

	# 트렁크는 헤이즐보다 위에 그린다. 헤이즐이 트렁크 뒤를 지나 나온다
	trunk = TRUNK_SCRIPT.new()
	trunk.scale = Vector2.ONE * TRUNK_RATIO
	trunk.visible = false
	add_child(trunk)
	props = PROPS_SCRIPT.new()

	_bubble = BUBBLE_SCRIPT.new()
	add_child(_bubble)


	_narr = _paper_panel(Color(C_PAPER, 0.92), 8, 10, 18)
	_narr_label = Label.new()
	_narr_label.add_theme_font_override("font", serif_italic)
	_narr_label.add_theme_font_size_override("font_size", 18)
	_narr_label.add_theme_color_override("font_color", C_MUTED)
	_narr.add_child(_narr_label)
	add_child(_narr)

	_user_box = _paper_panel(Color(1, 1, 1, 0.94), 10, 10, 18, C_LINK)
	_user_label = Label.new()
	_user_label.add_theme_font_size_override("font_size", 17)
	_user_label.add_theme_color_override("font_color", C_LINK)
	_user_box.add_child(_user_label)
	add_child(_user_box)

	_card = _paper_panel(Color("#FFFDF4"), 3, 10, 10, C_LINE)
	_card_label = Label.new()
	_card_label.add_theme_font_size_override("font_size", 15)
	_card_label.add_theme_color_override("font_color", C_TX)
	_card.add_child(_card_label)
	add_child(_card)

	_choice_panel = _paper_panel(Color(C_PAPER, 0.97), 12, 8, 8, C_LINE)
	_choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 0)
	_choice_panel.add_child(_choices)
	add_child(_choice_panel)


func _paper_panel(bg: Color, radius: int, pad_v: int, pad_h: int, border := Color.TRANSPARENT) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = false
	return p


## 한글 명조에 이탤릭 면이 없어 기울여서 흉내 낸다. 형태는 FontVariation 클래스 문서의 예시를 따랐다
func _serif_italic() -> FontVariation:
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Noto Serif KR", "Nanum Myeongjo", "Batang", "serif"])
	var v := FontVariation.new()
	v.base_font = serif
	v.variation_transform = Transform2D(Vector2(1.0, ITALIC_SLANT), Vector2(0.0, 1.0), Vector2.ZERO)
	return v


func _process(_delta: float) -> void:
	if _dragging:
		trunk.position.x = _view.position.x - _drag_dir * _drag_offset()
	if _bubble.visible:
		_place_bubble()


func _drag_offset() -> float:
	return 44.0 + TRUNK_SCRIPT.W * 0.5 * TRUNK_RATIO + 4.0


# ── 창 ──

func _ground_y() -> int:
	return DisplayServer.screen_get_usable_rect(get_window().current_screen).end.y


func foot_y() -> float:
	return float(get_window().size.y - _foot_margin)


## 1비트: 창을 넓혀 화면 오른쪽 아래에 붙인다. 창 오른쪽 가장자리가 곧 화면 가장자리다
func open_stage() -> void:
	var w := get_window()
	var rect := DisplayServer.screen_get_usable_rect(w.current_screen)
	w.size = STAGE_SIZE
	w.content_scale_size = STAGE_SIZE           # 1:1 로 그린다. 안 맞추면 늘어나 보인다
	w.position = Vector2i(rect.end.x - STAGE_SIZE.x, rect.end.y - STAGE_SIZE.y + _foot_margin)
	_view.visible = false
	_view.position = Vector2(STAGE_SIZE.x + 60, foot_y())


## 무대를 거둔다. 헤이즐이 셸 안에 있는 동안(2~4비트) 이 창은 모든 모니터 밖으로 치워둔다.
## 투명하게 비워둔 채 그 자리에 남겨두면, 셸을 그 모니터로 옮겼을 때 셸 오른쪽 아래(선택지 자리)와 겹쳐
## 선택지가 눌리지 않았다(2026-10-01 유저 보고). 비어 있는 투명 창이 클릭을 통과시키는지는 확인하지 않았다 —
## 그래서 통과 여부에 기대지 않고 겹칠 자리 자체를 없앤다.
## 주 창은 숨길 수 없다(실행 시 "Can't change visibility of main window"). 그래서 줄이고 밖으로 옮긴다.
## 크기·위치는 5비트 drop_in, 또는 중단 시 루트가 되돌린다
func close_stage() -> void:
	_hide_all()
	var w := get_window()
	w.size = HIDDEN_SIZE
	w.content_scale_size = HIDDEN_SIZE
	w.position = HIDDEN_POS
	_view.visible = false
	_view.position = Vector2(_win_size.x * 0.5, _win_size.y - _foot_margin)


func _hide_all() -> void:
	trunk.visible = false
	_bubble.visible = false
	_narr.visible = false
	_user_box.visible = false
	_card.visible = false
	_clear_choices()


# ── 기다림·헤이즐 ──

func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func set_face(f: int) -> void:
	_view.face = f


## 머리 위 말풍선. 바탕화면에서는 짧게만 말한다
func say(text: String, close := true, speaker := "") -> void:
	if speaker != "":
		_bubble.set_speaker(speaker)
	_bubble.set_text(text)
	_place_bubble()
	_bubble.visible = true
	var shown := 0.0
	while shown < text.length():
		shown += get_process_delta_time() / TYPE_SEC
		_bubble.label.visible_characters = int(shown)
		await get_tree().process_frame
	_bubble.label.visible_characters = -1
	await wait(DWELL_MIN + text.length() * DWELL_PER_CHAR)
	if close:
		_bubble.visible = false


## 창 안에서 x 까지 걷는다. drag 면 트렁크를 뒤에 끈다
func walk_to(x: float, drag := false) -> void:
	var dir := 1 if x > _view.position.x else -1
	_dragging = drag
	_drag_dir = dir
	var snd := Sound.play_sfx(&"drag") if drag else null
	_view.start_act(VIEW_SCRIPT.Act.WALK)
	_view.walk_dir = dir
	while (x - _view.position.x) * dir > 0.0:
		_view.position.x += dir * WALK_SPEED * get_process_delta_time()
		await get_tree().process_frame
	_view.position.x = x
	_dragging = false
	Sound.stop_sfx(snd)
	_view.stop_act()
	_view.walk_dir = dir                          # stop_act 가 방향을 되돌리므로 보던 쪽을 유지한다


## 창 오른쪽 밖(트렁크 뒤)에 헤이즐을 세운다. 걸어 나오면 트렁크 뒤를 지나온다
func appear_offstage() -> void:
	_view.position = Vector2(STAGE_SIZE.x + 50, foot_y())
	_view.walk_dir = -1
	_view.visible = true


func face_front() -> void:
	_view.walk_dir = 1


func look_around() -> void:
	_view.walk_dir = 1
	await wait(0.8)
	_view.walk_dir = -1
	await wait(1.0)


## 몸을 한 번 털어 옷매무새를 고친다
func shake_off() -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(_view, "scale:x", 1.06, 0.05)
		tw.tween_property(_view, "scale:x", 0.95, 0.05)
	tw.tween_property(_view, "scale:x", 1.0, 0.06)
	await tw.finished


## 화면 유리를 안쪽에서 count 번 두드린다. 두드릴 때마다 화면 쪽으로 살짝 다가온다.
## 소리 글자는 띄우지 않는다. 노크 소리가 대신한다
func knock(count: int) -> void:
	for i in count:
		Sound.play_sfx(&"knock")
		var tw := create_tween()
		tw.tween_property(_view, "scale", Vector2.ONE * 1.07, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_view, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		await wait(0.42)
	await wait(0.85)


## 트렁크가 창 오른쪽 가장자리 밖에서 x 까지 밀려 들어온다
func slide_trunk(x: float, t: float) -> void:
	trunk.visible = true
	var snd := Sound.play_sfx(&"drag")
	var tw := create_tween()
	tw.tween_property(trunk, "position:x", x, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	Sound.stop_sfx(snd)


func place_trunk_offstage() -> void:
	trunk.position = Vector2(STAGE_SIZE.x + 80, foot_y())
	trunk.visible = true


## 내레이터. 헤이즐 머리 위에 종이를 받쳐 작게 덧붙인다
func narrate(text: String) -> void:
	_narr_label.text = text
	await _rise(_narr, _view.position + Vector2(0, -HAZEL_HEIGHT - 120))
	await wait(2.0)
	await _fade_out(_narr)


## 유저의 말. 헤이즐 왼쪽 위에 조용히 떠오른다
func user_says(text: String) -> void:
	_user_label.text = text
	await _rise(_user_box, _view.position + Vector2(-190, -HAZEL_HEIGHT * 0.6))
	await wait(1.4)
	await _fade_out(_user_box)


## 헤이즐이 유리에 대어 보이는 카드
func show_card(text: String) -> void:
	_card_label.text = text
	await _rise(_card, _view.position + Vector2(0, -HAZEL_HEIGHT * 0.62))


func hide_card() -> void:
	await _fade_out(_card)


# ── 답을 받는 것 ──

## 선택지를 헤이즐 왼쪽에 띄우고 고른 번호를 돌려준다. click_opens 면 헤이즐을 눌러도 0번이다
func choose(labels: Array) -> int:
	_pending = null
	_clear_choices()
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.add_theme_font_size_override("font_size", 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.add_theme_color_override("font_color", C_LINK)
		b.pressed.connect(_answer.bind(i))
		_choices.add_child(b)
	_choice_panel.modulate.a = 0.0                # 크기가 잡히기 전 한 프레임은 안 보이게 둔다
	_choice_panel.visible = true
	await get_tree().process_frame
	var p := _choice_panel
	p.size = p.get_combined_minimum_size()
	p.position = Vector2(maxf(_view.position.x - 70.0 - p.size.x, 8.0), foot_y() - p.size.y - 10.0)
	p.modulate.a = 1.0
	var v: Variant = _pending if _pending != null else await _answered
	_pending = null
	_clear_choices()
	return int(v)


## 답은 항상 여기를 거친다. 받아둔 뒤 신호를 쏜다
func _answer(v: Variant) -> void:
	_pending = v
	_answered.emit(v)


func _clear_choices() -> void:
	_choice_panel.visible = false
	for c in _choices.get_children():
		_choices.remove_child(c)         # 같은 프레임에 트리에서 빼고 지운다(docs/architecture/list-rebuild.md)
		c.queue_free()


## 루트는 온보딩 동안 입력을 막는다. 여기서 헤이즐 몸을 누른 것만 받는다
func _unhandled_input(event: InputEvent) -> void:
	if not click_opens or not _view.visible:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := mb.position - _view.position
	if absf(local.x) < 50.0 and local.y < 0.0 and local.y > -HAZEL_HEIGHT:
		_answer(0)


# ── 5비트: 셸 가장자리에서 내려앉는다 ──

## 시메지 크기 창을 screen_foot(발바닥 화면 좌표)에 띄우고 바닥으로 떨어뜨린다
func drop_in(screen_foot: Vector2i) -> void:
	var w := get_window()
	w.size = _win_size
	w.content_scale_size = _win_size
	var foot_line := _win_size.y - _foot_margin
	_view.position = Vector2(_win_size.x * 0.5, foot_line)
	_view.walk_dir = 1
	_view.face = VIEW_SCRIPT.Face.NONE
	w.position = Vector2i(screen_foot.x - _win_size.x / 2, screen_foot.y - foot_line)
	_view.visible = true
	var target_y := _ground_y() - foot_line
	var v := 0.0
	while w.position.y < target_y:
		v += GRAVITY * get_process_delta_time()
		w.position = Vector2i(w.position.x, mini(w.position.y + int(v * get_process_delta_time()) + 1, target_y))
		await get_tree().process_frame
	_view.land()
	Sound.play_sfx(&"land")
	await wait(0.5)


## 창째로 걸어 화면 x(창 가운데)까지 간다. 지금 시메지의 걷기와 같은 방식이다
func walk_window_to(screen_x: int) -> void:
	var w := get_window()
	var cx := w.position.x + _win_size.x / 2
	var dir := 1 if screen_x > cx else -1
	_view.start_act(VIEW_SCRIPT.Act.WALK)
	_view.walk_dir = dir
	var fx := float(w.position.x)
	while (screen_x - (w.position.x + _win_size.x / 2)) * dir > 0:
		fx += dir * WALK_SPEED * get_process_delta_time()
		w.position = Vector2i(int(fx), w.position.y)
		await get_tree().process_frame
	_view.stop_act()
	_view.walk_dir = dir


## 수첩에 첫날을 적는다. 대사는 없다
func write_first_day() -> void:
	if props.get_parent() == null:
		_view.add_child(props)
	props.book = PROPS_SCRIPT.Book.HELD
	props.pencil = true
	Sound.play_sfx(&"book_open")
	Sound.play_sfx_repeat(&"write", 6, 0.28)
	await wait(2.4)
	props.pencil = false
	await wait(0.3)
	props.book = PROPS_SCRIPT.Book.NONE
	_view.remove_child(props)


# ── 내부 ──

## 조금 아래에서 스며들며 제자리로 온다. at 은 중심 자리
func _rise(c: Control, at: Vector2) -> void:
	c.visible = true
	c.modulate.a = 0.0
	await get_tree().process_frame
	c.size = c.get_combined_minimum_size()
	var target := at - c.size * 0.5
	target.x = clampf(target.x, 4.0, get_window().size.x - c.size.x - 4.0)
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
	var top := _view.position.y - HAZEL_HEIGHT - 20
	var ww := float(get_window().size.x)
	var bx := clampf(_view.position.x - _bubble.size.x * 0.5, 6, ww - _bubble.size.x - 6)
	_bubble.position = Vector2(bx, top - _bubble.size.y)
	_bubble.tail_x = _view.position.x - bx
	_bubble.queue_redraw()
