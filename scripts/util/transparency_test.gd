extends Node2D

## 투명 창 확인용 임시 씬.
##
## 지금 가리려는 것: 투명이 안 먹는 구역의 정체.
##   4 로 그리기를 끄면 창이 완전히 비어야 한다. 그래도 사각형이 남으면 배경 문제다.
##   5 로 클리어 컬러를 투명으로 바꿔 본다. 이때 사라지면 default_clear_color 가 범인이다.
##
## 조작 (작은 창이 포커스여도 먹는다)
##   1 — 폴리곤 모드: 없음 → 원 → 구석 사각형
##   2 — 말풍선 보이기/숨기기
##   3 — 클릭 수 초기화
##   4 — 그리기 모드: 전체 → 캐릭터만 → 창 테두리만 → 아무것도 안 그림
##   5 — 클리어 컬러를 투명으로 강제하기/되돌리기
##   ESC — 종료
##
## FPS 는 이 씬에서 Engine.max_fps 를 0 으로 눌러 둔다.
## Screen autoload 가 비포커스 때 10 으로 묶으므로 그대로 두면 성능 판정이 안 된다.

enum Poly { NONE, BODY, CORNER }
enum Draw { ALL, BODY_ONLY, FRAME_ONLY, NOTHING }

const WIN_SIZE := Vector2i(280, 340)
const BODY_CENTER := Vector2(140, 215)
const BODY_RADIUS := 72.0
const BUBBLE_RECT := Rect2(18, 16, 244, 64)
const CORNER_RECT := Rect2(6, 6, 46, 46)

var _win: Window
var _canvas: Node2D
var _win_label: Label
var _info: Label

var _poly := Poly.NONE
var _draw := Draw.ALL
var _bubble := false
var _clear_forced := false
var _clicks := 0
var _clear_original := Color(0, 0, 0, 1)


func _ready() -> void:
	get_tree().root.gui_embed_subwindows = false
	_clear_original = ProjectSettings.get_setting(
		"rendering/environment/defaults/default_clear_color", Color(0, 0, 0, 1))
	_build_main_ui()
	_build_window()
	_apply()


func _build_main_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.38, 0.58)
	bg.size = Vector2(1000, 700)
	add_child(bg)
	_info = Label.new()
	_info.position = Vector2(24, 24)
	_info.add_theme_font_size_override("font_size", 18)
	add_child(_info)


func _build_window() -> void:
	_win = Window.new()
	_win.title = "shimeji-test"
	_win.size = WIN_SIZE
	_win.borderless = true
	_win.always_on_top = true
	_win.transparent = true
	_win.transparent_bg = true
	_win.unresizable = true
	_win.window_input.connect(_on_window_input)
	add_child(_win)

	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_companion)
	_win.add_child(_canvas)

	_win_label = Label.new()
	_win_label.position = Vector2(8, 92)
	_win_label.add_theme_font_size_override("font_size", 14)
	_win_label.add_theme_color_override("font_color", Color(0.1, 0.09, 0.08))
	_win_label.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	_win_label.add_theme_constant_override("outline_size", 4)
	_win.add_child(_win_label)

	var rect := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	_win.position = rect.position + Vector2i(rect.size.x - WIN_SIZE.x - 80, 160)


func _draw_companion() -> void:
	if _draw == Draw.NOTHING:
		return
	# 창의 경계를 눈으로 잡으라고 긋는 선. 디버그용이라 일부러 튀는 색이다
	if _draw == Draw.ALL or _draw == Draw.FRAME_ONLY:
		_canvas.draw_rect(Rect2(Vector2.ONE, Vector2(WIN_SIZE) - Vector2.ONE * 2.0),
			Color(1, 0, 1), false, 2.0)
	if _draw == Draw.FRAME_ONLY:
		return
	_canvas.draw_circle(BODY_CENTER, BODY_RADIUS, Color(0.78, 0.71, 0.63))
	_canvas.draw_arc(BODY_CENTER, BODY_RADIUS, 0.0, TAU, 64, Color(0.29, 0.25, 0.22), 4.0)
	_canvas.draw_circle(BODY_CENTER + Vector2(-23, -15), 9.0, Color(0.29, 0.25, 0.22))
	_canvas.draw_circle(BODY_CENTER + Vector2(23, -15), 9.0, Color(0.29, 0.25, 0.22))
	if _draw != Draw.ALL:
		return
	if _poly == Poly.CORNER:
		_canvas.draw_rect(CORNER_RECT, Color(0.85, 0.35, 0.3))
	if _bubble:
		_canvas.draw_rect(BUBBLE_RECT, Color(0.97, 0.95, 0.91))
		_canvas.draw_rect(BUBBLE_RECT, Color(0.29, 0.25, 0.22), false, 3.0)


func _apply() -> void:
	match _poly:
		Poly.BODY:
			_win.mouse_passthrough_polygon = _circle_points()
		Poly.CORNER:
			_win.mouse_passthrough_polygon = PackedVector2Array([
				CORNER_RECT.position,
				Vector2(CORNER_RECT.end.x, CORNER_RECT.position.y),
				CORNER_RECT.end,
				Vector2(CORNER_RECT.position.x, CORNER_RECT.end.y),
			])
		_:
			_win.mouse_passthrough_polygon = PackedVector2Array()
	_win_label.visible = (_draw == Draw.ALL)
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()


func _circle_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(BODY_CENTER + Vector2(cos(a), sin(a)) * BODY_RADIUS)
	return pts


func _poly_name() -> String:
	match _poly:
		Poly.BODY:
			return "원"
		Poly.CORNER:
			return "구석 사각형"
		_:
			return "없음"


func _draw_name() -> String:
	match _draw:
		Draw.BODY_ONLY:
			return "캐릭터만"
		Draw.FRAME_ONLY:
			return "창 테두리만"
		Draw.NOTHING:
			return "아무것도 안 그림"
		_:
			return "전체"


func _process(_delta: float) -> void:
	Engine.max_fps = 0        # Screen autoload 가 되돌려 놓으므로 매 프레임 다시 누른다
	_info.text = "\n".join([
		"투명 창 확인",
		"",
		"FPS  %d" % Engine.get_frames_per_second(),
		"어댑터  %s" % RenderingServer.get_video_adapter_name(),
		"투명 지원  %s" % DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_TRANSPARENCY),
		"",
		"1  폴리곤  %s" % _poly_name(),
		"2  말풍선  %s" % ("보임" if _bubble else "숨김"),
		"3  클릭 수 초기화",
		"4  그리기  %s" % _draw_name(),
		"5  클리어 컬러 투명 강제  %s" % ("예" if _clear_forced else "아니오"),
		"ESC  종료",
		"",
		"작은 창이 받은 클릭  %d" % _clicks,
	])
	if _win_label.visible:
		_win_label.text = "폴리곤 %s\n클릭 %d" % [_poly_name(), _clicks]


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_clicks += 1
	_handle_key(event)


func _unhandled_key_input(event: InputEvent) -> void:
	_handle_key(event)


func _handle_key(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_poly = ((_poly + 1) % 3) as Poly
			_apply()
		KEY_2:
			_bubble = not _bubble
			_apply()
		KEY_3:
			_clicks = 0
		KEY_4:
			_draw = ((_draw + 1) % 4) as Draw
			_apply()
		KEY_5:
			_clear_forced = not _clear_forced
			RenderingServer.set_default_clear_color(
				Color(0, 0, 0, 0) if _clear_forced else _clear_original)
		KEY_ESCAPE:
			get_tree().quit()
