extends Node2D

## 헤이즐 리그 테스트 (임시 씬)
##
## 부위 분리 단계. 꼬리·몸·귀를 따로 두고 각자 움직인다.
##   그리는 순서는 꼬리 → 귀 → 몸. 귀가 몸보다 뒤다.
##   꼬리·귀·머리 윗부분은 따로 그린 그림이라 가려진 밑동까지 들어 있다.
##   그래서 크게 돌려도 잘린 면이 안 드러난다. 대신 귀를 몸 앞에 두면
##   그 밑동이 이마를 덮으므로 반드시 몸 뒤에 둔다.
## 눈 깜빡임은 몸 텍스처 교체로 처리한다. 눈은 따로 그린 그림이지만
## 빌드 단계(tools/split_hazel_parts.py)에서 몸통에 구워 넣으므로,
## 런타임이 할 일은 텍스처 세 장을 갈아끼우는 것뿐이다.
##
## 좌표는 전부 원본 스프라이트(173x302) 픽셀 기준이다.

const DIR := "res://assets/companion/rig/"
const META := DIR + "parts.json"

@export_group("숨쉬기")
@export var breath_period := 3.2
@export var breath_scale := 0.018
@export var breath_squash := 0.45

@export_group("몸 흔들림")
@export var sway_period := 7.4
@export var sway_degrees := 0.55

@export_group("부유")
@export var bob_period := 4.7
@export var bob_pixels := 1.6

@export_group("귀")
## 회전축(원본 스프라이트 좌표). 귀가 머리에서 빠져나오는 지점이다
@export var ear_l_pivot := Vector2(36, 100)
@export var ear_r_pivot := Vector2(116, 100)
@export var ear_sway_degrees := 1.4
@export var ear_sway_period := 5.3
## 좌우 위상을 어긋나게 해서 한 몸처럼 안 움직이게 한다
@export var ear_phase_offset := 1.7
@export_subgroup("움찔")
@export var ear_twitch_degrees := 7.0
@export var ear_twitch_interval_min := 3.0
@export var ear_twitch_interval_max := 9.0

@export_group("꼬리")
## 밑동. 따로 그린 꼬리라 몸 캔버스 오른쪽 밖까지 뻗는다(그래도 된다)
@export var tail_pivot := Vector2(130, 248)
@export var tail_sway_degrees := 2.6
@export var tail_sway_period := 6.1

@export_group("깜빡임")
@export var blink_interval_min := 2.4
@export var blink_interval_max := 6.8
@export var double_blink_chance := 0.22
@export var blink_close_time := 0.045
@export var blink_shut_time := 0.055
@export var blink_open_time := 0.070

@export_group("표시")
@export var sprite_scale := 1.6
@export var bg_color := Color("2a2622")
@export var ground_color := Color(1, 1, 1, 0.12)

const TWITCH_TIME := 0.35

var _rig: Node2D
var _deform: Node2D
var _sheet: Node2D
var _body: Sprite2D
var _ear_l: Sprite2D
var _ear_r: Sprite2D
var _tail: Sprite2D
var _eye := {}
var _size := Vector2i(173, 302)

var _t := 0.0
var _playing := true
var _ground_y := 0.0

## 표정 = 깜빡임이 끝나고 돌아갈 눈 상태. 버튼으로 바꾼다
var _expression := "open"
var _states: Array = []
var _buttons: HBoxContainer

var _blink_wait := 0.0
var _blink_steps: Array = []
var _blink_left := 0.0
var _eye_key := "open"

## 움찔 남은 시간(초). 0 이하면 쉬는 중
var _twitch := {"l": 0.0, "r": 0.0}
var _twitch_wait := 0.0

func _ready() -> void:
	randomize()
	var meta := _load_meta()
	if meta.is_empty():
		return
	_size = Vector2i(int(meta["size"]["w"]), int(meta["size"]["h"]))

	_rig = Node2D.new()
	_rig.name = "HazelRig"
	add_child(_rig)

	# 발밑이 원점. 여기에 스케일을 걸어야 숨쉴 때 위로만 부풀고 발이 안 뜬다
	_deform = Node2D.new()
	_deform.name = "Deform"
	_rig.add_child(_deform)

	# 이 아래로는 원본 스프라이트 좌표를 그대로 쓴다
	_sheet = Node2D.new()
	_sheet.name = "Sheet"
	_sheet.position = Vector2(-_size.x * 0.5, -_size.y)
	_deform.add_child(_sheet)

	# 추가 순서 = 그리는 순서. 귀 밑동이 이마를 덮지 않도록 몸을 마지막에 올린다
	_tail = _make_part("tail", meta, tail_pivot)
	_ear_l = _make_part("ear_l", meta, ear_l_pivot)
	_ear_r = _make_part("ear_r", meta, ear_r_pivot)
	_body = _make_body()
	if _body == null or _tail == null or _ear_l == null or _ear_r == null:
		return

	# 눈 상태 목록은 parts.json이 갖는다. 눈 소스에 줄을 더하면 여기도 늘어난다
	_states = meta.get("states", ["open"])
	for key in _states:
		_eye[key] = load(DIR + "hazel_body_%s.png" % key)

	var hint := Label.new()
	hint.text = "Space  정지/재생      B  깜빡이기      E  귀 움찔      R  리셋"
	hint.position = Vector2(16, 12)
	hint.modulate = Color(1, 1, 1, 0.45)
	add_child(hint)
	_build_buttons()

	_schedule_blink()
	_schedule_twitch()

## 상태 키 → 버튼에 쓸 이름. 없는 키는 키 그대로 쓴다
const STATE_LABEL := {
	"open": "기본", "half": "반쯤", "shut": "감음",
	"happy": "기쁨", "surprise": "놀람", "curious": "궁금", "excited": "신남",
}

func _build_buttons() -> void:
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	add_child(_buttons)
	for key in _states:
		var b := Button.new()
		b.text = STATE_LABEL.get(key, key)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_set_expression.bind(key))
		_buttons.add_child(b)

func _set_expression(key: String) -> void:
	if not _eye.has(key):
		return
	_expression = key
	# 깜빡이는 중이면 끝나고 알아서 새 표정으로 돌아온다
	if _blink_steps.is_empty() and _blink_left <= 0.0:
		_set_eyes(key)

func _load_meta() -> Dictionary:
	if not FileAccess.file_exists(META):
		push_error("parts.json 없음: %s" % META)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("parts.json 파싱 실패")
		return {}
	return parsed

## 부위 스프라이트. 회전축이 노드 원점에 오도록 offset을 잡는다
func _make_part(key: String, meta: Dictionary, pivot: Vector2) -> Sprite2D:
	var tex: Texture2D = load(DIR + "hazel_%s.png" % key)
	if tex == null:
		push_error("텍스처 없음: hazel_%s.png" % key)
		return null
	var box: Dictionary = meta[key]
	var s := Sprite2D.new()
	s.name = key
	s.texture = tex
	s.centered = false
	s.position = pivot
	s.offset = Vector2(float(box["x"]) - pivot.x, float(box["y"]) - pivot.y)
	_sheet.add_child(s)
	return s

func _make_body() -> Sprite2D:
	var tex: Texture2D = load(DIR + "hazel_body_open.png")
	if tex == null:
		push_error("텍스처 없음: hazel_body_open.png (에디터에서 임포트 필요할 수 있음)")
		return null
	var s := Sprite2D.new()
	s.name = "body"
	s.texture = tex
	s.centered = false
	_sheet.add_child(s)
	return s

func _process(delta: float) -> void:
	if _body == null:
		return
	if _playing:
		_t += delta
		_tick_blink(delta)
		_tick_twitch(delta)
	_apply_pose()
	queue_redraw()

func _apply_pose() -> void:
	var view := get_viewport_rect().size
	_ground_y = view.y * 0.82
	_rig.position = Vector2(view.x * 0.5, _ground_y)
	_rig.rotation_degrees = sin(_t * TAU / sway_period) * sway_degrees

	# 세로로 늘어난 만큼 가로를 줄여 부피 보존 인상을 준다
	var breath := sin(_t * TAU / breath_period)
	var sy := 1.0 + breath * breath_scale
	var sx := 1.0 - breath * breath_scale * breath_squash
	_deform.scale = Vector2(sx, sy) * sprite_scale
	_deform.position.y = sin(_t * TAU / bob_period) * -bob_pixels * sprite_scale

	# 귀 — 느린 흔들림에 움찔을 더한다. 좌우 부호를 뒤집어 바깥으로 벌어지게
	var base_l := sin(_t * TAU / ear_sway_period) * ear_sway_degrees
	var base_r := sin(_t * TAU / ear_sway_period + ear_phase_offset) * -ear_sway_degrees
	_ear_l.rotation_degrees = base_l - _twitch_angle("l")
	_ear_r.rotation_degrees = base_r + _twitch_angle("r")

	_tail.rotation_degrees = sin(_t * TAU / tail_sway_period) * tail_sway_degrees

	if _buttons != null:
		_buttons.position = Vector2(16, view.y - _buttons.size.y - 16)

## 감쇠 진동. 튕겼다가 잦아든다
func _twitch_angle(side: String) -> float:
	var left: float = _twitch[side]
	if left <= 0.0:
		return 0.0
	var e := TWITCH_TIME - left
	return ear_twitch_degrees * exp(-e * 11.0) * sin(e * TAU * 9.0)

func _tick_twitch(delta: float) -> void:
	for side in _twitch:
		if _twitch[side] > 0.0:
			_twitch[side] = maxf(0.0, _twitch[side] - delta)
	_twitch_wait -= delta
	if _twitch_wait <= 0.0:
		_start_twitch()

func _start_twitch() -> void:
	var side := "l" if randf() < 0.5 else "r"
	_twitch[side] = TWITCH_TIME
	_schedule_twitch()

func _schedule_twitch() -> void:
	_twitch_wait = randf_range(ear_twitch_interval_min, ear_twitch_interval_max)

# --- 깜빡임 ---------------------------------------------------------------

func _schedule_blink() -> void:
	_blink_wait = randf_range(blink_interval_min, blink_interval_max)

func _start_blink() -> void:
	# 감을 땐 빠르게, 뜰 땐 느리게. 이 비대칭이 없으면 눈꺼풀이 튕기는 느낌이 난다
	var one: Array = [
		["half", blink_close_time],
		["shut", blink_shut_time],
		["half", blink_open_time * 0.4],
		[_expression, blink_open_time * 0.6],
	]
	_blink_steps = one.duplicate(true)
	if randf() < double_blink_chance:
		_blink_steps.append([_expression, 0.09])
		_blink_steps.append_array(one.duplicate(true))
	_advance_blink()

func _advance_blink() -> void:
	if _blink_steps.is_empty():
		_set_eyes(_expression)
		_schedule_blink()
		return
	var step: Array = _blink_steps.pop_front()
	_set_eyes(step[0])
	_blink_left = step[1]

func _tick_blink(delta: float) -> void:
	if not _blink_steps.is_empty() or _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_advance_blink()
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_start_blink()

func _set_eyes(key: String) -> void:
	if key == _eye_key:
		return
	var tex: Texture2D = _eye.get(key)
	if tex == null:
		return
	_eye_key = key
	_body.texture = tex

# --- 그리기 ---------------------------------------------------------------

func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), bg_color)
	if _body == null:
		return

	# 바닥선 — 페르소나 §8의 "바닥선 있는 무대"를 임시로 표시
	draw_line(Vector2(0, _ground_y), Vector2(view.x, _ground_y), ground_color, 1.0)

	# 그림자 — 몸이 뜨면 좁아진다. 접지감을 만드는 건 그림자 쪽이다
	var lift := 1.0
	if bob_pixels > 0.0:
		lift = 1.0 - (_deform.position.y / (-bob_pixels * sprite_scale)) * 0.06
	var rx := _size.x * 0.34 * sprite_scale * lift
	draw_set_transform(Vector2(view.x * 0.5, _ground_y), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, rx, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_playing = not _playing
		KEY_B:
			if _blink_steps.is_empty() and _blink_left <= 0.0:
				_start_blink()
		KEY_E:
			_start_twitch()
		KEY_R:
			_t = 0.0
			_set_eyes(_expression)
			_blink_steps.clear()
			_blink_left = 0.0
			_twitch["l"] = 0.0
			_twitch["r"] = 0.0
			_schedule_blink()
			_schedule_twitch()
