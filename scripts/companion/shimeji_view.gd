class_name ShimejiView
extends Node2D

## 시메지의 몸. 파츠를 조립하고 포즈에 맞춰 각 파츠의 transform 을 매 프레임 정한다.
##
## 좌표는 docs/architecture/companion-rig.md 의 회전축 계약을 따른다 —
## 발바닥 중앙이 원점이고 위가 음수, 키는 약 160이다.
##
## 그리는 일은 ShimejiPart 가 하고 여기는 배치와 포즈만 맡는다.
## PNG 가 오면 파츠 쪽만 바뀌고 이 파일은 그대로다.
##
## 창을 옮기는 것과 떨어지는 것은 루트가 하고, 여기는 몸만 맡는다.

const PART_SCRIPT := preload("res://scripts/companion/shimeji_part.gd")

enum Pose { IDLE, LIFTED, LANDING, PET }
## 자기 일. 창을 옮기는 것은 루트가 하고 여기는 몸만 맡는다
enum Act { NONE, READ, WALK, BURY }

const SCRUFF := Vector2(0, -128)      # 들어올려질 때 매달리는 지점
const HEAD_CENTER := Vector2(0, -106)
const HEAD_RADIUS := 34.0
const FOREHEAD_TOP_Y := -114.0        # 눈 위쪽. 여기보다 위가 이마다

const BREATH_PERIOD := 3.2
const BLINK_MIN := 2.4
const BLINK_MAX := 6.8
const BLINK_TIME := 0.16
const PET_TIME := 0.9                 # 손을 뗀 뒤 쓰다듬김이 남아 있는 시간
const LAND_TIME := 0.42
const TWITCH_MIN := 3.0
const TWITCH_MAX := 9.0
const TWITCH_TIME := 0.26
const READ_TIME := 22.0
const PAGE_EVERY := 2.6
const BURY_TIME := 6.6

var pose := Pose.IDLE
var swing := 0.0                      # 들어올려졌을 때 몸이 도는 각도(도)
var act := Act.NONE
var walk_dir := 1                     # 걷는 방향. 몸 전체가 좌우로 뒤집힌다

var _rig: Node2D                      # 몸 전체에 걸리는 변형을 받는 자리
var _p := {}                          # 이름 → ShimejiPart

var _t := 0.0
var _blink_at := 3.0
var _blink_t := -1.0
var _open := 1.0
var _pet_t := -1.0
var _pet_held := false
var _land_t := -1.0

# 포즈가 바뀔 때 각도가 튀지 않게 목표값을 따라가기만 한다.
# 속도는 그 포즈의 제일 빠른 움직임을 못 따라가면 안 된다 — 쓰다듬기 꼬리가 초당 255도다.
var _tail_deg := 0.0
var _ear_deg := 0.0
var _head_deg := 0.0

var _twitch_at := 5.0
var _twitch_t := -1.0
var _act_t := 0.0
var _page_t := 0.0
var _page_flip := -1.0


## 그리는 순서. 앞이 뒤에 깔린다.
## 상수가 아니라 함수인 이유는 ShimejiPart.Kind 가 파스 시점에 잡히지 않아서다 —
## class_name 은 프로젝트를 다시 열기 전까지 전역 목록에 안 올라온다.
func _layout() -> Array:
	var K := PART_SCRIPT.Kind
	return [
		{"name": "tail", "kind": K.TAIL, "pivot": Vector2(16, -32)},
		{"name": "ear_l", "kind": K.EAR, "pivot": Vector2(-20, -124), "flip": true},
		{"name": "ear_r", "kind": K.EAR, "pivot": Vector2(20, -124)},
		{"name": "foot_l", "kind": K.FOOT, "pivot": Vector2(-16, -5)},
		{"name": "foot_r", "kind": K.FOOT, "pivot": Vector2(16, -5)},
		{"name": "body", "kind": K.BODY, "pivot": Vector2.ZERO},
		{"name": "cloak", "kind": K.CLOAK, "pivot": Vector2.ZERO},
		{"name": "bag", "kind": K.BAG, "pivot": Vector2.ZERO},
		{"name": "arm_l", "kind": K.ARM, "pivot": Vector2(-26, -60), "flip": true},
		{"name": "arm_r", "kind": K.ARM, "pivot": Vector2(26, -60)},
		{"name": "head", "kind": K.HEAD, "pivot": Vector2(0, -76)},
	]


## 소품. 몸과 따로 붙고 쓰이지 않을 때는 숨는다
func _prop_layout() -> Array:
	var K := PART_SCRIPT.Kind
	return [
		{"name": "ground", "kind": K.GROUND, "pivot": Vector2(0, -2)},
		{"name": "acorn", "kind": K.ACORN, "pivot": Vector2(0, -52)},
		{"name": "book", "kind": K.BOOK, "pivot": Vector2(0, -44)},
	]


func _ready() -> void:
	_blink_at = randf_range(BLINK_MIN, BLINK_MAX)
	_rig = Node2D.new()
	add_child(_rig)
	for item in _layout() + _prop_layout():
		var part: Node2D = PART_SCRIPT.new()
		part.setup(item["kind"], item["pivot"], item.get("flip", false))
		_rig.add_child(part)
		_p[item["name"]] = part
	_p["book"].visible = false
	_p["acorn"].visible = false
	_twitch_at = randf_range(TWITCH_MIN, TWITCH_MAX)


## 이마 판정. 좌표는 이 노드 기준(발바닥 원점)이다.
## 판정을 뷰가 갖는 이유는 파츠가 바뀌면 영역도 같이 움직여야 하기 때문이다.
## margin 은 히스테리시스용이다 — 들어갈 때는 0, 나갈 때는 넉넉히 줘서 손이 떨려도 안 끊긴다.
func is_forehead(p: Vector2, margin: float = 0.0) -> bool:
	if p.distance_to(HEAD_CENTER) > HEAD_RADIUS + margin:
		return false
	return p.y <= FOREHEAD_TOP_Y + margin


signal act_finished


func start_act(a: int) -> void:
	act = a
	_act_t = 0.0
	_page_t = 0.0
	_page_flip = -1.0


func stop_act() -> void:
	if act == Act.NONE:
		return
	act = Act.NONE
	walk_dir = 1
	act_finished.emit()


func is_acting() -> bool:
	return act != Act.NONE


func lift() -> void:
	stop_act()
	pose = Pose.LIFTED
	_pet_t = -1.0
	_pet_held = false
	_land_t = -1.0


func land() -> void:
	pose = Pose.LANDING
	_land_t = 0.0


func start_pet() -> void:
	if pose == Pose.LIFTED:
		return
	stop_act()
	pose = Pose.PET
	_pet_held = true
	_pet_t = -1.0


func stop_pet() -> void:
	if not _pet_held:
		return
	_pet_held = false
	_pet_t = 0.0                    # 손을 뗀 뒤 잠깐 남는다


func _process(delta: float) -> void:
	_t += delta
	_tick_timers(delta)
	_tick_twitch(delta)
	_tick_act(delta)
	if pose == Pose.IDLE:
		_tick_blink(delta)
	else:
		_open = move_toward(_open, _pose_openness(), delta * 6.0)
	_tail_deg = move_toward(_tail_deg, _tail_angle(), delta * 300.0)
	_ear_deg = move_toward(_ear_deg, _ear_droop(), delta * 120.0)
	_head_deg = move_toward(_head_deg, _head_tilt(), delta * 90.0)
	_apply_pose()


func _tick_timers(delta: float) -> void:
	if _land_t >= 0.0:
		_land_t += delta
		if _land_t >= LAND_TIME:
			_land_t = -1.0
			pose = Pose.IDLE
	if _pet_t >= 0.0 and not _pet_held:
		_pet_t += delta
		if _pet_t >= PET_TIME:
			_pet_t = -1.0
			pose = Pose.IDLE


## 귀 움찔. 평소 움직임이라 포즈와 무관하게 돈다
func _tick_twitch(delta: float) -> void:
	if _twitch_t < 0.0:
		_twitch_at -= delta
		if _twitch_at <= 0.0:
			_twitch_t = 0.0
		return
	_twitch_t += delta
	if _twitch_t >= TWITCH_TIME:
		_twitch_t = -1.0
		_twitch_at = randf_range(TWITCH_MIN, TWITCH_MAX)


func _twitch_deg() -> float:
	if _twitch_t < 0.0:
		return 0.0
	return sin(_twitch_t / TWITCH_TIME * TAU) * 8.0


## 자기 일의 시간. 걷기는 루트가 끝내므로 여기서 재지 않는다
func _tick_act(delta: float) -> void:
	if act == Act.NONE or pose == Pose.LIFTED:
		return
	_act_t += delta
	if act == Act.READ:
		_page_t += delta
		if _page_t >= PAGE_EVERY:
			_page_t = 0.0
			_page_flip = 0.0
		if _page_flip >= 0.0:
			_page_flip += delta / 0.5
			if _page_flip >= 1.0:
				_page_flip = -1.0
		if _act_t >= READ_TIME:
			stop_act()
	elif act == Act.BURY and _act_t >= BURY_TIME:
		stop_act()


func _tick_blink(delta: float) -> void:
	if _blink_t < 0.0:
		_blink_at -= delta
		if _blink_at <= 0.0:
			_blink_t = 0.0
		# 쓰다듬기에서 막 돌아온 눈은 여기서 제자리로 뜬다.
		# 이걸 빼면 실눈인 채로 다음 깜빡임까지 남는다
		_open = move_toward(_open, 1.0, delta * 6.0)
		return
	_blink_t += delta
	var k := _blink_t / BLINK_TIME
	if k >= 1.0:
		_blink_t = -1.0
		_blink_at = randf_range(BLINK_MIN, BLINK_MAX)
		_open = 1.0
	else:
		_open = 1.0 - sin(k * PI)


func _pose_openness() -> float:
	match pose:
		Pose.PET:
			return 0.16                     # 쓰다듬으면 실눈이 된다
		Pose.LANDING:
			return maxf(1.0 - sin(_land_t / LAND_TIME * PI) * 0.9, 0.1)
		_:
			return 1.0


func _tail_angle() -> float:
	match pose:
		Pose.LIFTED:
			return 46.0 - swing * 0.9       # 아래로 늘어지고 흔들림을 늦게 따라온다
		Pose.PET:
			return sin(_t * 15.0) * 17.0    # 빠르게 흔든다
		_:
			return sin(_t * 1.03) * 3.4


func _ear_droop() -> float:
	match pose:
		Pose.LIFTED:
			return 22.0
		Pose.PET:
			return 13.0
		_:
			return 0.0


func _head_tilt() -> float:
	match pose:
		Pose.LIFTED:
			return -swing * 0.3
		Pose.PET:
			return sin(_t * 2.4) * 4.0
		_:
			return 0.0


## 포즈를 파츠의 transform 으로 옮긴다. 매 프레임 전부 다시 정한다 —
## 이전 프레임의 값이 남아 포즈가 섞이는 일을 없애려는 것이다.
func _apply_pose() -> void:
	var breath := sin(_t * TAU / BREATH_PERIOD)
	var lifted := pose == Pose.LIFTED

	var root_dy := 0.0
	var body_sx := 1.0
	var body_sy := 1.0 + breath * 0.9 / 38.0
	var body_dy := 0.0
	var arm_l := 0.0
	var arm_r := 0.0
	var foot_l := Vector2(-16, -5)
	var foot_r := Vector2(16, -5)
	var head_dy := -breath * 1.2
	var head_deg := _head_deg
	var iris := Vector2.ZERO
	var open := _open
	var tail := _tail_deg
	var book := false
	var acorn := Vector2.INF        # INF 면 안 보인다
	var ground_grow := 0.0
	var ground_mound := false

	if lifted:
		foot_l += Vector2(-5, 6)
		foot_r += Vector2(5, 6)
		arm_l = 0.0
		arm_r = 0.0

	match act:
		Act.READ:
			root_dy = 16.0
			body_sx = 1.07
			body_sy = 0.9 + breath * 0.014
			foot_l = Vector2(-21, -2)
			foot_r = Vector2(21, -2)
			arm_l = 42.0
			arm_r = -42.0
			head_deg += 11.0
			head_dy += 2.0
			tail = -22.0 + sin(_t * 0.9) * 2.5
			open = minf(open, 0.44)
			iris = Vector2(0, 3.2)
			book = true
		Act.WALK:
			var ph := _t * 7.4
			body_dy = -absf(sin(ph)) * 3.2
			body_sy = 1.0 + sin(ph * 2.0) * 0.02
			foot_l = Vector2(-16 + cos(ph) * 6.0, -5 - maxf(0.0, sin(ph)) * 9.0)
			foot_r = Vector2(16 + cos(ph + PI) * 6.0, -5 - maxf(0.0, sin(ph + PI)) * 9.0)
			arm_l = sin(ph) * 17.0
			arm_r = sin(ph + PI) * 17.0
			tail = 8.0 + sin(ph * 0.5) * 11.0
			head_dy += body_dy * 0.8
			head_deg += -3.0
			iris = Vector2(2.4, 0)
		Act.BURY:
			var u := _act_t
			root_dy = 20.0 * clampf((u - 0.9) / 0.6, 0.0, 1.0) * (1.0 - clampf((u - 5.1) / 0.7, 0.0, 1.0))
			var crouch := root_dy / 20.0
			body_sy = lerpf(body_sy, 0.84, crouch)
			body_sx = lerpf(1.0, 1.1, crouch)
			foot_l = Vector2(-16 - 6.0 * crouch, -5)
			foot_r = Vector2(16 + 6.0 * crouch, -5)
			head_deg += lerpf(8.0, 20.0, crouch)
			iris = Vector2(0, 3.4)
			tail = lerpf(tail, -10.0, crouch)
			if u < 0.9:                                  # 가져옴
				arm_l = lerpf(0.0, 44.0, clampf(u / 0.6, 0.0, 1.0))
				acorn = Vector2(0, -52)
			elif u < 1.5:                                # 웅크림
				var k := (u - 0.9) / 0.6
				arm_l = lerpf(44.0, 22.0, k)
				acorn = Vector2(0, lerpf(-52.0, -40.0, k))
			elif u < 3.4:                                # 파기
				arm_l = 22.0 + sin(_t * 16.0) * 30.0
				acorn = Vector2(-2, -40)
				ground_grow = clampf((u - 1.5) / 1.6, 0.0, 1.0)
			elif u < 4.1:                                # 넣기
				var k := (u - 3.4) / 0.7
				arm_l = lerpf(22.0, 6.0, k)
				ground_grow = 1.0
				acorn = Vector2(-2, lerpf(-40.0, -8.0, k)) if k < 0.85 else Vector2.INF
			elif u < 5.1:                                # 덮기
				var k := (u - 4.1) / 1.0
				arm_l = 6.0 + absf(sin(k * PI * 3.0)) * 22.0
				ground_grow = k
				ground_mound = true
			else:                                        # 일어나서 본다
				arm_l = lerpf(28.0, 0.0, clampf((u - 5.1) / 0.7, 0.0, 1.0))
				ground_grow = 1.0
				ground_mound = true
				if u >= 5.8:
					head_deg += 10.0
			arm_r = -arm_l
		_:
			pass

	_rig.transform = _rig_transform(root_dy)

	_p["body"].scale = Vector2(body_sx, body_sy)
	_p["body"].position = Vector2(0, body_dy)
	_p["cloak"].position = Vector2(0, body_dy)
	_p["cloak"].scale = Vector2(body_sx, body_sy)
	_p["bag"].position = Vector2(0, body_dy)
	_p["bag"].scale = Vector2(body_sx, body_sy)
	_p["tail"].rotation_degrees = tail
	var tw := _twitch_deg()
	_p["ear_l"].rotation_degrees = -_ear_deg - tw
	_p["ear_r"].rotation_degrees = _ear_deg
	_p["ear_l"].position = Vector2(-20, -124 + body_dy)
	_p["ear_r"].position = Vector2(20, -124 + body_dy)
	_p["foot_l"].position = foot_l
	_p["foot_r"].position = foot_r
	_p["arm_l"].position = Vector2(-26 - (8.0 if lifted else 0.0), -60 + body_dy)
	_p["arm_r"].position = Vector2(26 + (8.0 if lifted else 0.0), -60 + body_dy)
	_p["arm_l"].rotation_degrees = arm_l
	_p["arm_r"].rotation_degrees = arm_r

	var head: Node2D = _p["head"]
	head.position = Vector2(0, -76 + head_dy + body_dy)
	head.rotation_degrees = head_deg
	head.open = open
	head.iris = iris
	head.mouth_curve = 6.0 if pose == Pose.PET else 2.5
	head.queue_redraw()

	var bk: Node2D = _p["book"]
	bk.visible = book
	if book:
		bk.position = Vector2(0, -44 + body_dy)
		bk.rotation_degrees = -7.0
		bk.page = maxf(_page_flip, 0.0)
		bk.queue_redraw()

	var ac: Node2D = _p["acorn"]
	ac.visible = acorn != Vector2.INF
	if ac.visible:
		ac.position = acorn
		ac.queue_redraw()

	var gd: Node2D = _p["ground"]
	gd.visible = ground_grow > 0.01
	if gd.visible:
		gd.grow = ground_grow
		gd.mound = ground_mound
		gd.queue_redraw()


## 몸 전체에 걸리는 변형. 들어올려지면 목덜미를 축으로 돌고 착지하면 발을 축으로 눌린다.
## 걷는 방향은 여기서 좌우 반전으로 낸다.
func _rig_transform(root_dy: float) -> Transform2D:
	var base := Transform2D(0.0, Vector2(float(walk_dir), 1.0), 0.0, Vector2(0, root_dy))
	if pose == Pose.LIFTED:
		var r := Transform2D(deg_to_rad(swing), Vector2.ZERO)
		return base * Transform2D(0.0, SCRUFF) * r * Transform2D(0.0, -SCRUFF)
	if pose == Pose.LANDING:
		var k := sin(_land_t / LAND_TIME * PI)
		return base * Transform2D(0.0, Vector2(1.0 + k * 0.26, 1.0 - k * 0.30), 0.0, Vector2.ZERO)
	return base
