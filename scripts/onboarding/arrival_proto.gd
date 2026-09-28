extends Control

## 온보딩 1비트 「부임」 프로토타입(A안: 바탕화면에 도착한다). 버리는 코드다.
##
## 무대가 둘이다.
## - 바탕화면: 이 씬의 주 창을 작업표시줄을 뺀 화면 크기의 투명 창으로 편다. 투명한 곳은 클릭이 통과한다
## - 대화 창: 헤이즐을 열어주면 뜨는 진짜 OS 창. 처음엔 비어 있다
##
## 톤은 코지다. 흔들림·암전 없이 간격과 절제로 웃긴다.
## 헤이즐은 해요체를 쓰는 초짜 집사다. 말은 서툴러도 손은 확실하다 — 그 갭이 매력이다.
## 대본은 아직 문서에 없는 초안이다. 방·소품은 도형이다.
## 저장을 건드리지 않는다. F6 로 이 씬만 띄우고, 끝내려면 끝의 종료 버튼이나 F8.

const VIEW_SCRIPT := preload("res://scripts/companion/shimeji_view.gd")

const HAZEL_HEIGHT := 160.0          # 리그 계약상 키
const DESK_SCALE := 1.0              # 바탕화면에서는 시메지 크기 그대로
const WIN_SCALE := 1.6
const TRUNK_RATIO := 0.95            # 헤이즐 배율 대비 트렁크 배율. 자기 몸만 하다
const DESK_WALK := 110.0
const WIN_WALK := 150.0
const FOOT_MARGIN := 30.0            # 바탕화면에서 발이 작업표시줄 위 이만큼
const KNOCK_AT := 0.3                # 두드리는 자리. 화면 폭 비율. 오른쪽에 대화 창이 열릴 자리를 남긴다
const DIALOG_SIZE := Vector2i(960, 600)
const DIALOG_FLOOR := 0.8

const TYPE_SPEED := 0.035
const DWELL_MIN := 0.9
const DWELL_PER_CHAR := 0.045
const RISE := 14.0
const RISE_TIME := 0.35
const ITALIC_SLANT := 0.2

const C_TX := Color("#221F1A")
const C_LINK := Color("#2C5578")
const C_LINE := Color("#2A2320")
const C_PAPER := Color("#FCFAF6")
const C_MUTED := Color("#6B5E50")

var _serif_italic: FontVariation
var _desk: Stage
var _win: Stage
var _dlg: Window
var _carry: Carry                     # 대화 창 헤이즐이 걸치고 드는 것
var _desk_carry: Carry                # 바탕화면 헤이즐 몫. 5비트에서 돌아온 뒤에 쓴다
var _skip := false
var _await_open := false

signal _name_decided(n: String)
signal _todo_decided(text: String)

# 4비트 선반. 대화 창 왼쪽에 도구가 한 줄로 선다 — 나중에 셸의 사이드바가 될 자리
const SHELF_X := 18.0
const SHELF_TOP := 30.0
const SHELF_GAP := 54.0
var _shelf: Array = []
var _todo_panel: PanelContainer


## 무대 하나에 딸린 것들. 바탕화면과 대화 창이 같은 연출 부품을 쓴다
class Stage:
	var canvas: Control
	var hazel: Node2D
	var scale: float
	var walk_speed: float
	var trunk: Trunk
	var bubble: Bubble
	var sfx: Label
	var card: PanelContainer
	var narr: PanelContainer
	var narr_label: Label
	var user_box: PanelContainer
	var user_label: Label
	var choice_panel: PanelContainer
	var choices: VBoxContainer
	var floor_y := 0.0
	var dragging := false
	var drag_dir := 1

	func drag_offset() -> float:
		return 44.0 * scale + Trunk.W * 0.5 * scale * TRUNK_RATIO + 4.0


func _ready() -> void:
	get_tree().root.gui_embed_subwindows = false   # 대화 창을 진짜 OS 창으로 띄운다
	_setup_overlay()
	_build_fonts()
	_desk = _make_stage(self, DESK_SCALE, DESK_WALK, true)
	_desk_carry = Carry.new()
	_desk.hazel.add_child(_desk_carry)
	_build_dialog()
	await get_tree().process_frame     # 크기가 잡힌 뒤에 자리를 계산한다
	_run()


## 주 창을 바탕화면 무대로 편다. 작업표시줄은 덮지 않는다
func _setup_overlay() -> void:
	var w := get_window()
	var rect := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	w.borderless = true
	w.transparent = true
	w.always_on_top = true
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	w.position = rect.position
	w.size = rect.size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_fonts() -> void:
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Noto Serif KR", "Nanum Myeongjo", "Batang", "serif"])
	_serif_italic = FontVariation.new()
	_serif_italic.base_font = serif
	# 한글 명조에 이탤릭 면이 없어 기울여서 흉내 낸다. 형태는 FontVariation 클래스 문서의 예시를 따랐다
	_serif_italic.variation_transform = Transform2D(Vector2(1.0, ITALIC_SLANT), Vector2(0.0, 1.0), Vector2.ZERO)


func _build_dialog() -> void:
	_dlg = Window.new()
	_dlg.title = "Voyager"
	_dlg.size = DIALOG_SIZE
	_dlg.unresizable = true
	_dlg.always_on_top = true
	_dlg.visible = false
	add_child(_dlg)
	_dlg.close_requested.connect(get_tree().quit)
	var canvas := Control.new()
	_dlg.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = C_PAPER
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var floor_line := ColorRect.new()
	floor_line.color = Color(C_LINE, 0.35)
	floor_line.position = Vector2(0, DIALOG_SIZE.y * DIALOG_FLOOR)
	floor_line.size = Vector2(DIALOG_SIZE.x, 2)
	floor_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(floor_line)
	canvas.gui_input.connect(_on_click_anywhere)
	_win = _make_stage(canvas, WIN_SCALE, WIN_WALK, false)
	# 리그 위에 얹는다. 헤이즐 배율을 그대로 탄다
	_carry = Carry.new()
	_win.hazel.add_child(_carry)


func _make_stage(canvas: Control, s: float, walk: float, on_desk: bool) -> Stage:
	var st := Stage.new()
	st.canvas = canvas
	st.scale = s
	st.walk_speed = walk

	# 헤이즐을 트렁크보다 먼저 붙인다. 트렁크 뒤로 지나가면 가려진다
	st.hazel = VIEW_SCRIPT.new()
	st.hazel.scale = Vector2.ONE * s
	canvas.add_child(st.hazel)
	st.trunk = Trunk.new()
	st.trunk.scale = Vector2.ONE * s * TRUNK_RATIO
	canvas.add_child(st.trunk)

	st.bubble = Bubble.new()
	canvas.add_child(st.bubble)

	# 소리. 작고 흐리게. 바탕화면은 배경이 제각각이라 테두리를 준다
	st.sfx = Label.new()
	st.sfx.add_theme_font_override("font", _serif_italic)
	st.sfx.add_theme_font_size_override("font_size", 22 if on_desk else 26)
	st.sfx.add_theme_color_override("font_color", C_MUTED)
	if on_desk:
		st.sfx.add_theme_color_override("font_outline_color", C_PAPER)
		st.sfx.add_theme_constant_override("outline_size", 8)
	st.sfx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(st.sfx)

	# 헤이즐이 유리에 대어 보이는 카드
	st.card = PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("#FFFDF4")
	cs.border_color = C_LINE
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(3)
	cs.set_content_margin_all(10)
	st.card.add_theme_stylebox_override("panel", cs)
	st.card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_label := Label.new()
	card_label.text = "잠깐 들어가도 될까요?"
	card_label.add_theme_color_override("font_color", C_TX)
	card_label.add_theme_font_size_override("font_size", 15)
	st.card.add_child(card_label)
	canvas.add_child(st.card)

	# 내레이터. 작게 덧붙인다. 바탕화면에서는 읽히게 종이를 받친다
	st.narr = PanelContainer.new()
	if on_desk:
		var ns := StyleBoxFlat.new()
		ns.bg_color = Color(C_PAPER, 0.92)
		ns.set_corner_radius_all(8)
		ns.set_content_margin_all(10)
		ns.content_margin_left = 18
		ns.content_margin_right = 18
		st.narr.add_theme_stylebox_override("panel", ns)
	else:
		st.narr.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	st.narr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.narr_label = Label.new()
	st.narr_label.add_theme_font_override("font", _serif_italic)
	st.narr_label.add_theme_color_override("font_color", C_MUTED)
	st.narr_label.add_theme_font_size_override("font_size", 20 if on_desk else 22)
	st.narr.add_child(st.narr_label)
	canvas.add_child(st.narr)

	st.user_box = PanelContainer.new()
	var us := StyleBoxFlat.new()
	us.bg_color = Color(1, 1, 1, 0.94)
	us.set_corner_radius_all(10)
	us.set_content_margin_all(12)
	us.content_margin_left = 20
	us.content_margin_right = 20
	us.border_color = C_LINK
	us.set_border_width_all(2)
	st.user_box.add_theme_stylebox_override("panel", us)
	st.user_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.user_label = Label.new()
	st.user_label.add_theme_color_override("font_color", C_LINK)
	st.user_label.add_theme_font_size_override("font_size", 18 if on_desk else 22)
	st.user_box.add_child(st.user_label)
	canvas.add_child(st.user_box)

	st.choice_panel = PanelContainer.new()
	var cb := StyleBoxFlat.new()
	cb.bg_color = Color(C_PAPER, 0.97)
	cb.set_corner_radius_all(12)
	cb.set_content_margin_all(10)
	cb.border_color = C_LINE
	cb.set_border_width_all(2)
	st.choice_panel.add_theme_stylebox_override("panel", cb)
	canvas.add_child(st.choice_panel)
	st.choices = VBoxContainer.new()
	st.choices.add_theme_constant_override("separation", 0)
	st.choice_panel.add_child(st.choices)
	return st


func _reset_stage(st: Stage) -> void:
	st.hazel.visible = false
	st.hazel.stop_act()
	st.hazel.walk_dir = 1
	st.hazel.face = VIEW_SCRIPT.Face.NONE
	st.hazel.scale = Vector2.ONE * st.scale
	st.trunk.visible = false
	st.trunk.opened = false
	st.dragging = false
	st.bubble.visible = false
	st.sfx.visible = false
	st.card.visible = false
	st.narr.visible = false
	st.user_box.visible = false
	_clear_choices(st)


# ── 1부: 바탕화면 ──

func _run() -> void:
	_reset_stage(_desk)
	_reset_stage(_win)
	_dlg.hide()
	_carry.apron = false
	_carry.book = Carry.Book.NONE
	_carry.blush = false
	_carry.sweat = false
	_carry.pencil = false
	_desk_carry.apron = false
	_desk_carry.book = Carry.Book.NONE
	_desk_carry.pencil = false
	_win.trunk.scale = Vector2.ONE * _win.scale * TRUNK_RATIO
	_clear_beat4()
	_await_open = false
	var w := size.x
	_desk.floor_y = size.y - FOOT_MARGIN
	_win.floor_y = DIALOG_SIZE.y * DIALOG_FLOOR
	var fy := _desk.floor_y

	# 평소
	await _wait(3.0)

	# 전조. 화면 가장자리 밖에서 트렁크가 밀려 들어온다
	_desk.trunk.position = Vector2(w + 80, fy)
	_desk.trunk.visible = true
	_show_sfx(_desk, "드르륵……", Vector2(w - 150, fy - 150))
	await _tween_x(_desk.trunk, w - 50, 1.3)
	await _fade_out(_desk.sfx)
	await _wait(0.9)
	_show_sfx(_desk, "드르륵……", Vector2(w - 170, fy - 150))
	await _tween_x(_desk.trunk, w - 140, 1.1)
	await _fade_out(_desk.sfx)
	await _wait(1.0)

	# 등장. 트렁크 뒤를 지나 한 발 옆으로 나온다
	_desk.hazel.position = Vector2(w + 50, fy)
	_desk.hazel.visible = true
	await _walk_to(_desk, w - 250, -1)
	await _wait(0.6)

	# 둘러본다. 오른쪽, 왼쪽, 그리고 아이콘이 있는 쪽을 한 번
	_desk.hazel.walk_dir = 1
	await _wait(0.8)
	_desk.hazel.walk_dir = -1
	await _wait(1.0)
	await _shake_off(_desk)
	await _wait(0.5)

	# 트렁크를 끌고 화면 쪽으로 걸어온다
	await _drag_to(_desk, w * KNOCK_AT, -1)
	await _wait(0.6)
	_desk.hazel.walk_dir = 1           # 정면을 본다

	# 두드림
	await _knock(_desk, 3)
	await _wait(0.4)
	await _narrate(_desk, "— 안쪽에서 두드렸다.")
	_await_open = true
	_show_desk_choices(true)


func _show_desk_choices(full: bool) -> void:
	var items := [["(열어준다)", _on_open]]
	if full:
		items.append(["...누구세요?", _on_who])
		items.append(["(못 본 척한다)", _on_ignore])
	await _show_choices(_desk, items)


func _on_who() -> void:
	_clear_choices(_desk)
	await _user_says(_desk, "...누구세요?")
	await _wait(0.6)
	_face(_desk, VIEW_SCRIPT.Face.FLUSTERED)
	await _say(_desk, "아... 집사예요.", true, "???")
	await _narrate(_desk, "— 들리는 모양이다.")
	await _wait(0.3)
	await _knock(_desk, 1)
	_show_desk_choices(false)


func _on_ignore() -> void:
	_clear_choices(_desk)
	await _user_says(_desk, "(못 본 척한다)")
	await _hold(3.0)
	var card := _desk.card
	card.visible = true
	await get_tree().process_frame
	card.size = card.get_combined_minimum_size()
	card.position = _desk.hazel.position + Vector2(-card.size.x * 0.5, -HAZEL_HEIGHT * _desk.scale * 0.72)
	await _wait(1.6)
	await _narrate(_desk, "— 정말로 기다린다.")
	card.visible = false
	_show_desk_choices(false)


## 선택지 A 이거나 바탕화면의 헤이즐을 직접 누른 경우
func _on_open() -> void:
	if not _await_open:
		return
	_await_open = false
	_clear_choices(_desk)
	_desk.bubble.visible = false
	await _enter_dialog()


# ── 2부: 대화 창 ──

func _enter_dialog() -> void:
	# 헤이즐 바로 오른쪽에 창이 열린다
	var overlay_pos := get_window().position
	var left := int(_desk.hazel.position.x + 140)
	left = mini(left, int(size.x) - DIALOG_SIZE.x - 20)
	var top := int(size.y) - DIALOG_SIZE.y - 60
	_dlg.position = overlay_pos + Vector2i(left, top)
	_dlg.show()
	await _wait(0.8)

	# 트렁크를 끌고 창 왼쪽 가장자리로 들어간다
	await _drag_to(_desk, left + 10, 1)
	_desk.hazel.visible = false
	_desk.trunk.visible = false
	_desk.dragging = false

	var fy := _win.floor_y
	_win.hazel.position = Vector2(-70, fy)
	_win.hazel.visible = true
	_win.trunk.position = Vector2(-70 - _win.drag_offset(), fy)
	_win.trunk.visible = true
	await _drag_to(_win, DIALOG_SIZE.x * 0.34, 1)
	_win.dragging = false
	await _wait(0.4)
	await _wipe_feet(_win)
	await _wait(0.3)
	await _bow(_win)
	_face(_win, VIEW_SCRIPT.Face.FLUSTERED, false, true)
	await _say(_win, "아, 저... 처음 뵙겠습니다.", true, "???")
	_face(_win, VIEW_SCRIPT.Face.SOFT)
	await _say(_win, "오늘부터 여기 일을 맡게 됐어요.", false)
	await _show_choices(_win, [
		["...누가 보냈어요?", _on_who_sent],
		["일이요? 무슨 일이요?", _on_what_job],
		["(말없이 내려다본다)", _on_look_down],
	])


func _begin_answer(text: String) -> void:
	_clear_choices(_win)
	_win.bubble.visible = false
	await _user_says(_win, text)
	await _wait(0.6)                 # 반 박자


func _on_who_sent() -> void:
	await _begin_answer("...누가 보냈어요?")
	_face(_win, VIEW_SCRIPT.Face.SOFT)
	await _say(_win, "아무도요.", false)
	await _hold(0.6)
	_face(_win, VIEW_SCRIPT.Face.SHY, true, false)
	await _say(_win, "...제가 왔어요.")
	await _finish()


func _on_what_job() -> void:
	await _begin_answer("일이요? 무슨 일이요?")
	_face(_win, VIEW_SCRIPT.Face.SMILE)
	await _say(_win, "집사 일이요.", false)
	await _hold(0.6)
	_face(_win, VIEW_SCRIPT.Face.FLUSTERED, false, true)
	await _say(_win, "자세한 건... 천천히 말씀드릴게요.")
	await _finish()


func _on_look_down() -> void:
	await _begin_answer("(말없이 내려다본다)")
	_face(_win, VIEW_SCRIPT.Face.SURPRISED)
	await _hold(1.8)                 # 둘 다 말이 없다
	_face(_win, VIEW_SCRIPT.Face.SHY, true)
	await _bow(_win)
	await _finish()


func _finish() -> void:
	await _wait(0.4)
	# 트렁크를 창 한쪽에 반듯이 세운다
	await _tween_x(_win.trunk, DIALOG_SIZE.x * 0.16, 0.5)
	await _wait(0.3)
	_win.hazel.walk_dir = 1
	_face(_win, VIEW_SCRIPT.Face.SHY, true, false)
	await _say(_win, "아, 인사가 늦었네요. 헤이즐이에요.", false, "???")
	await _flip_name(_win, "헤이즐")
	await _wait(0.5)
	_win.trunk.opened = true
	await _wait(0.8)
	_face(_win, VIEW_SCRIPT.Face.SMILE)
	await _say(_win, "짐은 이게 다예요. 금방 풀게요.", false)
	await _beat2()


# ── 2비트: 이유 ──

func _beat2() -> void:
	await _wait(0.6)
	_win.bubble.visible = false
	# 짐을 푼다. 손이 빠르고 망설임이 없다
	await _quick_reach(_win)
	_carry.apron = true
	await _wait(0.3)
	await _quick_reach(_win)
	_carry.book = Carry.Book.HELD
	await _wait(0.8)
	await _show_choices(_win, [
		["그래서... 왜 온 건데요?", _b2_why],
		["(트렁크 안을 들여다본다)", _b2_peek],
		["집사가 뭘 하는데요?", _b2_what],
	])


func _b2_why() -> void:
	await _begin_answer("그래서... 왜 온 건데요?")
	_face(_win, VIEW_SCRIPT.Face.FLUSTERED, false, true)
	await _say(_win, "아, 그게...", false)
	await _explain()


func _b2_peek() -> void:
	await _begin_answer("(트렁크 안을 들여다본다)")
	_carry.book = Carry.Book.RAISED  # 수첩을 들어 보인다
	_face(_win, VIEW_SCRIPT.Face.SMILE)
	await _say(_win, "이거 때문에요.", false)
	_carry.book = Carry.Book.HELD
	await _explain()


func _b2_what() -> void:
	await _begin_answer("집사가 뭘 하는데요?")
	_face(_win, VIEW_SCRIPT.Face.THINK)
	await _say(_win, "음... 제일 중요한 것부터 말씀드릴게요.", false)
	await _explain()


func _explain() -> void:
	# 왜
	_face(_win, VIEW_SCRIPT.Face.SOFT)
	await _say(_win, "저희는 날들을 모아요. 좋은 날도, 그냥 그런 날도요.", false)
	await _say(_win, "마음에도 겨울이 오거든요.", false)
	await _hold(1.0)
	_face(_win, VIEW_SCRIPT.Face.SMILE)
	await _say(_win, "그때 꺼내 볼 게 있으면... 좀 덜 추워요.", false)
	_face(_win, VIEW_SCRIPT.Face.SHY, true, false)
	await _say(_win, "선배들은 다들 한 분씩 맡아서 모아요. 저는... 아직 수습이고요.", false)
	# 무엇을
	_face(_win, VIEW_SCRIPT.Face.NONE)
	await _say(_win, "그래서 여기서 할 일은요.", false)
	_face(_win, VIEW_SCRIPT.Face.SOFT)
	await _say(_win, "하실 일을 적어두고, 잊지 않게 챙겨드릴게요.", false)
	await _say(_win, "하루가 끝나면 그날 걸 같이 모아두고요.", false)
	_face(_win, VIEW_SCRIPT.Face.SMILE)
	await _say(_win, "아무것도 안 한 날도 적어요. 그것도 하루니까요.", false)
	await _show_choices(_win, [
		["...그럼 잘 부탁해요.", _b2_ok],
		["아직 믿는다고는 안 했어요.", _b2_doubt],
		["(수첩을 본다)", _b2_book],
	])


func _b2_ok() -> void:
	await _begin_answer("...그럼 잘 부탁해요.")
	await _hop(_win)                 # 꼬리가 한 번 크게 — 리그에 없어 몸으로 대신한다
	_face(_win, VIEW_SCRIPT.Face.SMILE)
	await _say(_win, "네.", false)
	await _beat3()


func _b2_doubt() -> void:
	await _begin_answer("아직 믿는다고는 안 했어요.")
	_face(_win, VIEW_SCRIPT.Face.SOFT)
	await _say(_win, "네. 천천히요.", false)
	await _hold(1.5)                 # 재촉하지 않고 기다린다
	await _beat3()


func _b2_book() -> void:
	await _begin_answer("(수첩을 본다)")
	_carry.book = Carry.Book.OPEN    # 첫 장을 펼쳐 보인다. 비어 있다
	await _wait(0.6)
	_face(_win, VIEW_SCRIPT.Face.SMILE)
	await _say(_win, "여기서부터 시작이에요.", false)
	await _beat3()


# ── 3비트: 이름 ──

func _beat3() -> void:
	await _wait(0.8)
	_win.bubble.visible = false
	_face(_win, VIEW_SCRIPT.Face.NONE)
	_carry.book = Carry.Book.OPEN    # 수첩 첫 장을 편다
	await _wait(0.5)
	_carry.pencil = true
	await _wait(0.4)
	# 연필을 깎는다. 손이 빠르다
	_show_sfx(_win, "슥, 슥.", _book_top())
	await _quick_reach(_win)
	await _wait(0.15)
	await _quick_reach(_win)
	await _wait(0.4)
	await _fade_out(_win.sfx)
	_face(_win, VIEW_SCRIPT.Face.THINK)
	await _say(_win, "그럼... 제일 먼저 적어둘 게 있어요.", false)
	_face(_win, VIEW_SCRIPT.Face.SOFT)
	await _say(_win, "어떻게 불러드리면 될까요?", false)
	var n := (await _ask_name()).strip_edges()
	if n == "":
		await _b3_blank()
	else:
		await _b3_named(n)
	await _beat4()


# ── 4비트: 짐 풀기(도구 소개) ──

func _beat4() -> void:
	await _wait(0.8)
	_win.bubble.visible = false
	_face(_win, VIEW_SCRIPT.Face.NONE)
	_carry.book = Carry.Book.NONE    # 수첩도 짐이다. 선반으로 간다
	_carry.pencil = false
	# 자리를 잡는다. 왼쪽 선반과 말풍선이 겹치지 않게
	await _walk_to(_win, DIALOG_SIZE.x * 0.45, 1)
	await _wait(0.3)
	var items := [
		[ShelfItem.Kind.NOTEBOOK, "할 일", "하실 일은 여기 적어두세요. 잊지 않게 챙길게요.", VIEW_SCRIPT.Face.SOFT, false],
		[ShelfItem.Kind.CARD, "습관", "매일 하고 싶은 건 여기요.", VIEW_SCRIPT.Face.SOFT, false],
		[ShelfItem.Kind.TIMER, "타이머", "집중할 땐 이걸 돌려요. 도는 동안은 조용히 있을게요.", VIEW_SCRIPT.Face.SOFT, false],
		[ShelfItem.Kind.DIARY, "일지", "쓰고 싶은 날엔 여기에요.", VIEW_SCRIPT.Face.SMILE, false],
		[ShelfItem.Kind.ACORNS, "기록", "이건... 제 거예요. 모은 날들이 여기 들어가요.", VIEW_SCRIPT.Face.SHY, true],
	]
	for i in items.size():
		await _unpack(items[i], i)
	await _wait(0.5)
	_win.bubble.visible = false
	_face(_win, VIEW_SCRIPT.Face.NONE, false)
	await _wait(0.4)

	# 수첩을 유저 쪽으로 민다
	await _pulse(_shelf[0])
	_face(_win, VIEW_SCRIPT.Face.SOFT)
	await _say(_win, "하나만 적어볼래요? 큰 거 아니어도 돼요.", false)
	await _wait(0.3)
	_win.bubble.visible = false
	var t := (await _open_todo_mock()).strip_edges()
	if t != "":
		await _wait(0.9)             # 슬쩍 들여다본다
		await _close_todo_mock()
		_face(_win, VIEW_SCRIPT.Face.SMILE)
		await _say(_win, "적어두셨네요. 제가 기억해 둘게요.", false)
	else:
		await _close_todo_mock()
		_face(_win, VIEW_SCRIPT.Face.SOFT)
		await _say(_win, "네. 수첩은 여기 둘게요.", false)
		await _pulse(_shelf[0])      # 수첩이 제자리로 돌아간다
	await _beat5()


# ── 5비트: 물러남 ──

func _beat5() -> void:
	await _wait(0.8)
	_win.bubble.visible = false
	_face(_win, VIEW_SCRIPT.Face.NONE)
	# 빈 트렁크로 가서 접는다. 한 번, 두 번
	var tr := _win.trunk
	await _walk_to(_win, tr.position.x + _win.drag_offset(), -1)
	await _wait(0.3)
	tr.opened = false
	var s := tr.scale.x
	for k in [0.6, 0.3]:
		await _quick_reach(_win)
		var tw := create_tween()
		tw.tween_property(tr, "scale", Vector2.ONE * s * k, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw.finished
		await _wait(0.35)
	await _quick_reach(_win)
	tr.visible = false               # 앞치마 주머니에 넣는다
	await _wait(0.5)
	await _narrate(_win, "— 어떻게 들어가는 건지 모르겠다.")
	_win.hazel.walk_dir = 1
	_face(_win, VIEW_SCRIPT.Face.SOFT)
	await _say(_win, "그럼 저는 밖에 있을게요.", false)
	_face(_win, VIEW_SCRIPT.Face.SMILE)
	await _say(_win, "필요하시면 불러주세요.", false)
	await _show_choices(_win, [
		["고마워요.", _b5_thanks],
		["(손을 흔든다)", _b5_wave],
	])


func _b5_thanks() -> void:
	await _begin_answer("고마워요.")
	_face(_win, VIEW_SCRIPT.Face.SHY, true)
	await _bow(_win)
	await _wait(0.4)
	await _b5_leave()


func _b5_wave() -> void:
	await _begin_answer("(손을 흔든다)")
	_face(_win, VIEW_SCRIPT.Face.SMILE)
	await _sway(_win)                # 손 흔들기 — 리그에 없어 몸을 좌우로 흔드는 것으로 대신한다
	await _wait(0.3)
	await _b5_leave()


## 셸 창 오른쪽 가장자리로 나가서 바탕화면으로 내려앉고, 트렁크가 들어왔던 자리로 간다
func _b5_leave() -> void:
	_face(_win, VIEW_SCRIPT.Face.NONE)
	await _walk_to(_win, DIALOG_SIZE.x + 70, 1)
	_win.hazel.visible = false

	# 창 오른쪽 가장자리의 바닥 높이에서 바탕화면으로 나온다
	var off := _dlg.position - get_window().position
	var start := Vector2(off.x + DIALOG_SIZE.x + 24, off.y + _win.floor_y)
	var h := _desk.hazel
	h.position = start
	h.walk_dir = 1
	h.face = VIEW_SCRIPT.Face.NONE
	_desk_carry.apron = true
	h.visible = true
	var drop := maxf(_desk.floor_y - start.y, 0.0)
	var tw := create_tween()
	tw.tween_property(h, "position:y", _desk.floor_y, sqrt(drop / 1000.0) + 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	h.land()
	await _wait(0.6)
	await _walk_to(_desk, size.x - 150, 1)
	await _wait(0.5)

	# 둘러보고, 수첩에 첫날을 적는다. 대사는 없다
	h.walk_dir = -1
	await _wait(0.8)
	h.walk_dir = 1
	await _wait(0.6)
	_desk_carry.book = Carry.Book.HELD
	_desk_carry.pencil = true
	_show_sfx(_desk, "사각, 사각.", h.position + Vector2(40, -HAZEL_HEIGHT * _desk.scale - 10))
	await _wait(1.8)
	await _fade_out(_desk.sfx)
	_desk_carry.pencil = false
	await _quick_reach(_desk)
	_desk_carry.book = Carry.Book.NONE
	await _wait(1.0)
	await _end_proto()


## 좌우로 몸을 흔든다
func _sway(st: Stage) -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(st.hazel, "rotation_degrees", 6.0, 0.12)
		tw.tween_property(st.hazel, "rotation_degrees", -6.0, 0.12)
	tw.tween_property(st.hazel, "rotation_degrees", 0.0, 0.1)
	await tw.finished


## 트렁크에서 하나 꺼내 선반으로 옮기고 한 줄 소개한다
func _unpack(it: Array, i: int) -> void:
	await _quick_reach(_win)
	var item := ShelfItem.new()
	item.setup(it[0], it[1])
	_win.canvas.add_child(item)
	_shelf.append(item)
	var tr := _win.trunk
	if i == 4:
		tr.opened = false            # 마지막 짐이다. 빈 트렁크를 닫는다
	item.position = tr.position + Vector2(-ShelfItem.ICON * 0.5, -Trunk.H * tr.scale.y - 50)
	item.modulate.a = 0.0
	var to := Vector2(SHELF_X, SHELF_TOP + i * SHELF_GAP)
	var tw := create_tween().set_parallel()
	tw.tween_property(item, "modulate:a", 1.0, 0.2)
	tw.tween_property(item, "position", to, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_face(_win, it[3], it[4])
	await _say(_win, it[2], false)


func _pulse(c: Control) -> void:
	c.pivot_offset = Vector2(ShelfItem.ICON, ShelfItem.ICON) * 0.5
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * 1.18, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


## 할 일 화면 흉내. 진짜 도구를 붙이면 실제 todo.json 에 쓰게 되므로 모양만 낸다.
## 한 줄 적으면 그 문자열, 「나중에 할게요」면 빈 문자열
func _open_todo_mock() -> String:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = Color(C_LINE, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2(560, 60)
	p.custom_minimum_size = Vector2(370, 380)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var title := Label.new()
	title.text = "할 일"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", C_TX)
	v.add_child(title)
	var row := HBoxContainer.new()
	v.add_child(row)
	var edit := LineEdit.new()
	edit.placeholder_text = "할 일 추가"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	var add := Button.new()
	add.text = "추가"
	row.add_child(add)
	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(list)
	var later := Button.new()
	later.text = "나중에 할게요"
	later.flat = true
	later.size_flags_horizontal = Control.SIZE_SHRINK_END
	later.add_theme_color_override("font_color", C_MUTED)
	v.add_child(later)
	var submit := func(text: String) -> void:
		if text.strip_edges() == "":
			return
		var l := Label.new()
		l.text = "☐  " + text.strip_edges()
		l.add_theme_color_override("font_color", C_TX)
		list.add_child(l)
		edit.clear()
		edit.editable = false
		add.disabled = true
		later.disabled = true
		_todo_decided.emit(text)
	add.pressed.connect(func() -> void: submit.call(edit.text))
	edit.text_submitted.connect(func(s: String) -> void: submit.call(s))
	later.pressed.connect(func() -> void: _todo_decided.emit(""))
	_todo_panel = p
	_win.canvas.add_child(p)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.3)
	edit.grab_focus()
	var t: String = await _todo_decided
	return t


func _close_todo_mock() -> void:
	if _todo_panel == null:
		return
	await _fade_out(_todo_panel)
	_win.canvas.remove_child(_todo_panel)
	_todo_panel.queue_free()
	_todo_panel = null


func _clear_beat4() -> void:
	for n in _shelf:
		n.get_parent().remove_child(n)
		n.queue_free()
	_shelf.clear()
	if _todo_panel != null:
		_todo_panel.get_parent().remove_child(_todo_panel)
		_todo_panel.queue_free()
		_todo_panel = null


## 이름 입력 칸. 비워두거나 "나중에"를 고르면 빈 문자열
func _ask_name() -> String:
	_clear_choices(_win)
	var edit := LineEdit.new()
	edit.placeholder_text = "이름"
	edit.max_length = 12
	edit.custom_minimum_size = Vector2(240, 0)
	edit.add_theme_font_size_override("font_size", 20)
	_win.choices.add_child(edit)
	var ok := Button.new()
	ok.text = "(알려준다)"
	var later := Button.new()
	later.text = "...그건 나중에요."
	for b in [ok, later]:
		b.add_theme_font_size_override("font_size", 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.add_theme_color_override("font_color", C_LINK)
		_win.choices.add_child(b)
	ok.pressed.connect(func() -> void: _name_decided.emit(edit.text))
	edit.text_submitted.connect(func(t: String) -> void: _name_decided.emit(t))
	later.pressed.connect(func() -> void: _name_decided.emit(""))
	await _place_choice_panel(_win)
	edit.grab_focus()
	var n: String = await _name_decided
	_clear_choices(_win)
	return n


func _b3_named(n: String) -> void:
	_win.bubble.visible = false
	_face(_win, VIEW_SCRIPT.Face.SOFT)
	# 받아 적는다. 또박또박, 빠르지 않다
	_show_sfx(_win, "사각, 사각.", _book_top())
	await _wait(1.6)
	await _quick_reach(_win)         # 한 획을 고쳐 긋는다
	await _wait(0.5)
	await _fade_out(_win.sfx)
	_carry.pencil = false
	_carry.book = Carry.Book.HELD    # 가슴에 안는다
	await _wait(0.6)
	_face(_win, VIEW_SCRIPT.Face.SHY, true)
	await _say(_win, "%s님." % n, false)
	await _hop(_win)                 # 꼬리가 한 번 크게 — 리그에 없어 몸으로 대신한다
	await _hold(0.5)
	await _say(_win, "%s님... %s님." % [n, n], false)
	await _narrate(_win, "— 연습하고 있다.")
	_face(_win, VIEW_SCRIPT.Face.SMILE)
	await _say(_win, "외웠어요.", false)


func _b3_blank() -> void:
	_win.bubble.visible = false
	await _user_says(_win, "...그건 나중에요.")
	await _wait(0.5)
	_face(_win, VIEW_SCRIPT.Face.SOFT)
	await _say(_win, "...네.", false)
	_carry.pencil = false            # 연필을 내려놓는다
	await _wait(0.4)
	await _say(_win, "그럼 부르지 않을게요.", false)
	await _quick_reach(_win)         # 첫 장을 비워둔 채 다음 장으로 넘긴다
	await _narrate(_win, "— 첫 장은 비워두었다.")


## 펼친 수첩 위쪽. 소리 글자를 띄우는 자리
func _book_top() -> Vector2:
	return _win.hazel.position + Vector2(32, -128) * _win.scale


func _end_proto() -> void:
	await _show_choices(_win, [
		["처음부터 다시 (프로토)", _run],
		["종료 (프로토)", get_tree().quit],
	])


# ── 대사 ──

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


## 클릭으로 건너뛸 수 있는 기다림
func _hold(t: float) -> void:
	_skip = false
	while t > 0.0 and not _skip:
		t -= get_process_delta_time()
		await get_tree().process_frame
	_skip = false


## 머리 위 말풍선에 지금 하는 말 하나만 띄운다. 클릭하면 즉시 완성, 한 번 더 누르면 넘어간다
func _say(st: Stage, text: String, close := true, speaker := "") -> void:
	if speaker != "":
		st.bubble.set_speaker(speaker)
	st.bubble.set_text(text)
	_place_bubble(st)
	st.bubble.visible = true
	_skip = false
	var shown := 0.0
	while shown < text.length():
		if _skip:
			break
		shown += get_process_delta_time() / TYPE_SPEED
		st.bubble.label.visible_characters = int(shown)
		await get_tree().process_frame
	st.bubble.label.visible_characters = -1
	await _hold(DWELL_MIN + text.length() * DWELL_PER_CHAR)
	if close:
		st.bubble.visible = false


## 표정을 바꾼다. 홍조·땀은 대화 창 헤이즐에만 있다
func _face(st: Stage, f: int, blush := false, sweat := false) -> void:
	st.hazel.face = f
	if st == _win:
		_carry.blush = blush
		_carry.sweat = sweat


## 이름표가 뒤집히며 이름이 드러난다
func _flip_name(st: Stage, speaker: String) -> void:
	var tag := st.bubble.tag
	tag.pivot_offset = tag.size * 0.5
	var tw := create_tween()
	tw.tween_property(tag, "scale:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	st.bubble.set_speaker(speaker)
	tag.pivot_offset = tag.size * 0.5
	var back := create_tween()
	back.tween_property(tag, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished


## 유저의 말. 바탕화면에서는 헤이즐 옆에, 대화 창에서는 발밑에 조용히 떠오른다
func _user_says(st: Stage, text: String) -> void:
	st.user_label.text = text
	var at: Vector2
	if st == _desk:
		at = st.hazel.position + Vector2(210, -HAZEL_HEIGHT * st.scale * 0.5)
	else:
		at = st.canvas.size * Vector2(0.5, 0.9)
	await _rise(st.user_box, at)
	await _hold(1.4)
	await _fade_out(st.user_box)


func _narrate(st: Stage, text: String) -> void:
	st.narr_label.text = text
	var at: Vector2
	if st == _desk:
		at = st.hazel.position + Vector2(0, -HAZEL_HEIGHT * st.scale - 110)
	else:
		at = st.canvas.size * Vector2(0.5, 0.1)
	await _rise(st.narr, at)
	await _hold(2.0)
	await _fade_out(st.narr)


func _show_sfx(st: Stage, text: String, at: Vector2) -> void:
	st.sfx.text = text
	_rise(st.sfx, at)


## 화면 유리를 안쪽에서 두드린다. 두드릴 때마다 몸이 화면 쪽으로 살짝 다가온다
func _knock(st: Stage, times: int) -> void:
	var s := st.scale
	var text := ""
	var at := st.hazel.position + Vector2(70, -HAZEL_HEIGHT * s * 0.85)
	for i in times:
		text += ("" if i == 0 else " ") + "똑."
		st.sfx.text = text
		if i == 0:
			_rise(st.sfx, at)
		var tw := create_tween()
		tw.tween_property(st.hazel, "scale", Vector2.ONE * s * 1.07, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(st.hazel, "scale", Vector2.ONE * s, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
		await _wait(0.42)
	await _wait(0.6)
	await _fade_out(st.sfx)


## 조금 아래에서 스며들며 제자리로 온다. at 은 중심 자리
func _rise(box: Control, at: Vector2) -> void:
	box.visible = true
	box.modulate.a = 0.0
	await get_tree().process_frame
	box.size = box.get_combined_minimum_size()
	var target := at - box.size * 0.5
	box.position = target + Vector2(0, RISE)
	var tw := create_tween().set_parallel()
	tw.tween_property(box, "modulate:a", 1.0, RISE_TIME)
	tw.tween_property(box, "position", target, RISE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


func _fade_out(box: CanvasItem) -> void:
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 0.0, 0.25)
	await tw.finished
	box.visible = false


func _show_choices(st: Stage, items: Array) -> void:
	_clear_choices(st)
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.add_theme_font_size_override("font_size", 17 if st == _desk else 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.add_theme_color_override("font_color", C_LINK)
		b.pressed.connect(it[1])
		st.choices.add_child(b)
	await _place_choice_panel(st)


func _place_choice_panel(st: Stage) -> void:
	st.choice_panel.visible = true
	await get_tree().process_frame
	var p := st.choice_panel
	p.size = p.get_combined_minimum_size()
	if st == _desk:
		p.position = st.hazel.position + Vector2(110, -p.size.y - 20)
	else:
		p.position = Vector2(st.canvas.size.x - p.size.x - 30, st.canvas.size.y - p.size.y - 20)


func _clear_choices(st: Stage) -> void:
	st.choice_panel.visible = false
	for c in st.choices.get_children():
		st.choices.remove_child(c)
		c.queue_free()


# ── 동작 ──

func _tween_x(node: Node2D, x: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "position:x", x, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _walk_to(st: Stage, x: float, dir: int) -> void:
	st.hazel.start_act(VIEW_SCRIPT.Act.WALK)
	st.hazel.walk_dir = dir
	while (x - st.hazel.position.x) * dir > 0.0:
		st.hazel.position.x += dir * st.walk_speed * get_process_delta_time()
		await get_tree().process_frame
	st.hazel.position.x = x
	st.hazel.stop_act()
	st.hazel.walk_dir = dir          # stop_act 가 방향을 되돌리므로 보던 쪽을 유지한다


## 트렁크를 뒤에 끌며 걷는다
func _drag_to(st: Stage, x: float, dir: int) -> void:
	st.dragging = true
	st.drag_dir = dir
	await _walk_to(st, x, dir)


## 몸을 한 번 털어 옷매무새를 고친다
func _shake_off(st: Stage) -> void:
	var s := st.scale
	var tw := create_tween()
	for i in 3:
		tw.tween_property(st.hazel, "scale:x", s * 1.06, 0.05)
		tw.tween_property(st.hazel, "scale:x", s * 0.95, 0.05)
	tw.tween_property(st.hazel, "scale:x", s, 0.06)
	await tw.finished


## 인사. 리그에 인사 동작이 없어 몸을 눌렀다 펴는 것으로 대신한다
func _bow(st: Stage) -> void:
	var s := st.scale
	var tw := create_tween()
	tw.tween_property(st.hazel, "scale", Vector2(s * 1.03, s * 0.84), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(st.hazel, "scale", Vector2(s, s), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## 트렁크에 손을 넣었다 빼는 것. 몸을 짧게 눌렀다 편다
func _quick_reach(st: Stage) -> void:
	var s := st.scale
	var tw := create_tween()
	tw.tween_property(st.hazel, "scale", Vector2(s * 1.02, s * 0.92), 0.09)
	tw.tween_property(st.hazel, "scale", Vector2(s, s), 0.11)
	await tw.finished


## 작게 한 번 뛴다
func _hop(st: Stage) -> void:
	var y := st.hazel.position.y
	var tw := create_tween()
	tw.tween_property(st.hazel, "position:y", y - 14.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(st.hazel, "position:y", y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


## 문턱에서 발을 턴다. 왼발, 오른발, 다시 왼발
func _wipe_feet(st: Stage) -> void:
	var base := st.hazel.position.x
	for dx in [-7.0, 7.0, -7.0]:
		var tw := create_tween()
		tw.tween_property(st.hazel, "position:x", base + dx * st.scale / WIN_SCALE * 1.4, 0.12)
		tw.tween_property(st.hazel, "position:x", base, 0.12)
		await tw.finished
		await _wait(0.12)


func _place_bubble(st: Stage) -> void:
	var b := st.bubble
	var top := st.hazel.position.y - HAZEL_HEIGHT * st.scale - 24
	var bx := clampf(st.hazel.position.x - b.size.x * 0.5, 16, st.canvas.size.x - b.size.x - 16)
	b.position = Vector2(bx, top - b.size.y)
	b.tail_x = st.hazel.position.x - bx
	b.queue_redraw()


func _process(_delta: float) -> void:
	for st in [_desk, _win]:
		if st == null:
			continue
		if st.dragging:
			st.trunk.position.x = st.hazel.position.x - st.drag_dir * st.drag_offset()
		if st.bubble.visible:
			_place_bubble(st)


## 바탕화면에서는 그려진 픽셀만 클릭을 받는다. 헤이즐을 누르면 열어주는 것이다
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_skip = true
	if _await_open and _desk.hazel.visible:
		var local := mb.position - _desk.hazel.position
		if absf(local.x) < 50.0 * _desk.scale and local.y < 0.0 and local.y > -HAZEL_HEIGHT * _desk.scale:
			_on_open()


func _on_click_anywhere(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_skip = true


# ── 트렁크 ──

class Trunk extends Node2D:
	const W := 118.0
	const H := 104.0
	var opened := false :
		set(v):
			opened = v
			queue_redraw()

	## 원점은 바닥 중앙
	func _draw() -> void:
		var body := Rect2(-W * 0.5, -H, W, H)
		draw_rect(body, Color("#7B4B2E"))
		draw_rect(body, C_LINE, false, 4.0)
		for sx in [-W * 0.25, W * 0.25]:
			draw_rect(Rect2(sx - 6, -H, 12, H), Color("#4E3020"))
		draw_rect(Rect2(-18, -H - 12, 36, 12), Color("#4E3020"))      # 손잡이
		# 도토리 스티커
		draw_circle(Vector2(26, -H * 0.42), 11, Color("#C88A4A"))
		draw_rect(Rect2(14, -H * 0.42 - 16, 24, 8), Color("#6B4426"))
		if opened:
			draw_rect(Rect2(-W * 0.5, -H - 60, W, 54), Color("#6A3F26"))    # 열린 뚜껑
			draw_rect(Rect2(-W * 0.5, -H - 60, W, 54), C_LINE, false, 4.0)
			draw_rect(Rect2(-W * 0.5 + 8, -H + 6, W - 16, 30), Color("#2E1E14"))
			draw_rect(Rect2(-44, -H + 2, 40, 22), Color("#F3EEE4"))          # 접힌 앞치마
			draw_rect(Rect2(2, -H - 2, 26, 30), Color("#3C4A5C"))            # 닳은 수첩
			for i in 3:
				draw_circle(Vector2(38 + i * 7, -H + 16 - i * 3), 6, Color("#C88A4A"))   # 도토리


# ── 걸치고 드는 것 ──

## 앞치마와 수첩. 헤이즐 노드의 자식이라 좌표는 리그 계약(발바닥 원점, 위가 음수)을 따른다
class Carry extends Node2D:
	enum Book { NONE, HELD, RAISED, OPEN }
	var apron := false :
		set(v):
			apron = v
			queue_redraw()
	var book := Book.NONE :
		set(v):
			book = v
			queue_redraw()
	var blush := false :
		set(v):
			blush = v
			queue_redraw()
	var sweat := false :
		set(v):
			sweat = v
			queue_redraw()
	var pencil := false :
		set(v):
			pencil = v
			queue_redraw()

	func _draw() -> void:
		# 얼굴 위에 얹는 표시. 머리 기울기는 따라가지 않는다
		if blush:
			for x in [-21.0, 21.0]:
				draw_set_transform(Vector2(x, -93), 0.0, Vector2(1.0, 0.55))
				draw_circle(Vector2.ZERO, 7.0, Color(0.93, 0.45, 0.45, 0.55))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if sweat:
			var c := Vector2(34, -122)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(-5, 0), c + Vector2(5, 0)]), Color("#A9D2EC"))
			draw_circle(c, 5.0, Color("#A9D2EC"))
			draw_arc(c, 5.0, 0.0, PI, 10, C_LINE, 1.2)
		if apron:
			draw_line(Vector2(-15, -58), Vector2(-22, -74), C_LINE, 2.0)   # 끈
			draw_line(Vector2(15, -58), Vector2(22, -74), C_LINE, 2.0)
			draw_rect(Rect2(-17, -58, 34, 42), Color("#F3EEE4"))
			draw_rect(Rect2(-17, -58, 34, 42), C_LINE, false, 2.0)
		match book:
			Book.HELD:
				_notebook(Rect2(-6, -54, 18, 24))
			Book.RAISED:
				_notebook(Rect2(24, -104, 20, 26))
			Book.OPEN:
				for r in [Rect2(10, -106, 22, 28), Rect2(32, -106, 22, 28)]:
					draw_rect(r, Color("#FFFDF4"))
					draw_rect(r, C_LINE, false, 1.5)
		if pencil:
			draw_line(Vector2(56, -74), Vector2(44, -98), C_LINE, 5.0)
			draw_line(Vector2(56, -74), Vector2(45, -96), Color("#E2B34A"), 3.0)
			draw_circle(Vector2(44, -98), 1.8, C_LINE)                    # 심

	func _notebook(r: Rect2) -> void:
		draw_rect(r, Color("#3C4A5C"))
		draw_rect(r, C_LINE, false, 1.5)


# ── 선반의 도구 ──

class ShelfItem extends Control:
	enum Kind { NOTEBOOK, CARD, TIMER, DIARY, ACORNS }
	const ICON := 40.0
	var kind := Kind.NOTEBOOK

	func setup(k: Kind, text: String) -> void:
		kind = k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(140, ICON)
		var l := Label.new()
		l.text = text
		l.add_theme_color_override("font_color", C_TX)
		l.add_theme_font_size_override("font_size", 17)
		l.position = Vector2(ICON + 10, 8)
		add_child(l)

	func _draw() -> void:
		match kind:
			Kind.NOTEBOOK:
				draw_rect(Rect2(8, 4, 24, 32), Color("#3C4A5C"))
				draw_rect(Rect2(8, 4, 24, 32), C_LINE, false, 2.0)
			Kind.CARD:
				draw_rect(Rect2(4, 6, 32, 28), Color("#FFFDF4"))
				draw_rect(Rect2(4, 6, 32, 28), C_LINE, false, 2.0)
				for i in 3:
					var o := Vector2(9 + i * 9, 20)
					draw_polyline(PackedVector2Array([o, o + Vector2(2, 3), o + Vector2(6, -4)]), Color("#6E8B5A"), 2.0)
			Kind.TIMER:
				draw_rect(Rect2(17, 4, 6, 6), C_LINE)
				draw_circle(Vector2(20, 23), 14, Color("#D9B25A"))
				draw_arc(Vector2(20, 23), 14, 0, TAU, 24, C_LINE, 2.0)
				draw_line(Vector2(20, 23), Vector2(20, 14), C_LINE, 2.0)
			Kind.DIARY:
				draw_rect(Rect2(6, 4, 28, 32), Color("#8A5A3C"))
				draw_rect(Rect2(6, 4, 28, 32), C_LINE, false, 2.0)
				draw_rect(Rect2(26, 4, 4, 18), Color("#B5654E"))       # 가름끈
			Kind.ACORNS:
				draw_rect(Rect2(4, 20, 32, 16), Color("#7B4B2E"))
				draw_rect(Rect2(4, 20, 32, 16), C_LINE, false, 2.0)
				for i in 3:
					draw_circle(Vector2(12 + i * 8, 16 - (i % 2) * 3), 5, Color("#C88A4A"))


# ── 말풍선 ──

class Bubble extends Control:
	const PAD := 16.0
	const TAIL := 14.0
	var label: Label
	var tag: PanelContainer
	var _tag_label: Label
	var tail_x := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		label.add_theme_color_override("font_color", C_TX)
		label.add_theme_font_size_override("font_size", 20)
		label.position = Vector2(PAD, PAD)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		# 비주얼 노벨식 이름표. 말풍선 왼쪽 위에 걸친다
		tag = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = C_LINE
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		tag.add_theme_stylebox_override("panel", sb)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tag_label = Label.new()
		_tag_label.add_theme_color_override("font_color", Color("#F3EEE4"))
		_tag_label.add_theme_font_size_override("font_size", 15)
		tag.add_child(_tag_label)
		add_child(tag)
		set_speaker("???")

	func set_speaker(s: String) -> void:
		_tag_label.text = s
		tag.size = tag.get_combined_minimum_size()
		tag.position = Vector2(14, -tag.size.y + 6)

	func set_text(t: String) -> void:
		label.text = t
		label.visible_characters = 0
		# 한 줄 폭을 폰트로 직접 잰 뒤 너무 길면 묶는다. 줄바꿈이 찍히는 동안 바뀌지 않게 먼저 확정한다
		var font := label.get_theme_font("font")
		var fs := label.get_theme_font_size("font_size")
		var w := minf(font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0, 560.0)
		w = maxf(w, tag.size.x + 20.0)
		var h := font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
		label.size = Vector2(w, h)
		size = Vector2(w + PAD * 2, h + PAD * 2)

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.97)
		sb.set_corner_radius_all(14)
		sb.border_color = C_LINE
		sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var tx := clampf(tail_x, 24.0, size.x - 24.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx - 12, size.y - 2), Vector2(tx + 12, size.y - 2), Vector2(tail_x, size.y + TAIL)]),
			Color(1, 1, 1, 0.97))
