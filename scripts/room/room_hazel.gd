extends Node2D

## 방 안의 헤이즐(docs/specs/settings.md 의 "내보내기 — 방으로 들어간다").
## 바탕화면에서 내보내면 헤이즐은 자기 방으로 들어간다. 헤이즐은 한 번에 한 곳에만 있다 —
## 바탕화면에 있는 동안은 방에 없고, 방에 있는 동안은 바탕화면에 없다.
##
## 셸 상단 방(배너)의 자식이다. 방 좌표로 서고, 방이 잘라내므로 가장자리 밖으로 걸어 나가면 안 보인다.
## 몸은 시메지와 같은 리그(shimeji_view.gd)를 줄여 쓴다. 지내는 규칙도 시메지와 같다 —
## 평소엔 숨·깜빡임만, 가끔 자기 일(읽기·도토리 묻기·방 안 걷기), 쪽지가 꽂히면 수첩에 적는다.

signal left_room                       # 방 밖으로 걸어 나갔다. 바탕화면으로 돌아가는 걸음이 이걸 기다린다

const VIEW_SCRIPT := preload("res://scripts/companion/shimeji_view.gd")
# 자기 일 간격과 걷기 시간은 시메지와 같은 값이다(shimeji_root.gd). 그 파일을 preload 하면
# 셸 씬 → 배너 → 이 파일 → 시메지 루트 → 셸 씬으로 순환하므로 값을 옮겨 적는다. 바꿀 때 같이 바꾼다
const ACT_GAP_RELEASE := Vector2(14400.0, 28800.0)
const ACT_GAP_DEBUG := Vector2(8.0, 18.0)
const WALK_TIME_RELEASE := Vector2(12.0, 25.0)
const WALK_TIME_DEBUG := Vector2(7.0, 12.0)

const ROOM_SCALE := 0.55               # 리그 키 약 160 → 약 88. 방 바닥선(배너 높이의 0.82) 아래에 들어간다. F6에서 눈으로 조정할 값
const HOME_X := 250.0                  # 제자리. 책장과 책상 사이다. 방 좌표
const DOOR_X := -40.0                  # 들고 나는 자리. 방 왼쪽 가장자리 밖
const WALK_MIN_X := 40.0               # 방 안 걷기의 범위. 창문부터 트렁크 앞까지
const WALK_MAX_X := 400.0
const WALK_SPEED := 25.0               # 방 크기에 맞춘 걸음. 시메지 걸음(46)을 배율만큼 줄였다
const DOOR_SPEED := 60.0               # 들고 나는 걸음은 조금 빠르다

enum State { OUT, ENTERING, HERE, LEAVING }

var room: Control                      # 이 헤이즐이 사는 방(hazel_room.gd). 바닥 높이를 여기서 읽는다
var view: VIEW_SCRIPT
var paused := false                    # 부르기 동안 자기 일을 멈춘다. 대화 모드가 셸을 덮고 있다

var _state := State.OUT
var _x := HOME_X
var _act_wait := 0.0
var _walk_left := 0.0


func _ready() -> void:
	view = VIEW_SCRIPT.new()
	view.scale = Vector2.ONE * ROOM_SCALE
	view.visible = false
	add_child(view)
	view.act_finished.connect(_schedule_act)
	_schedule_act()


## 방에 들어온다. walk 면 왼쪽 가장자리에서 걸어 들어오고, 아니면 제자리에 바로 선다(셸이 닫혀 있어 안 보일 때)
func enter(walk: bool) -> void:
	view.visible = true
	view.stop_act()
	_walk_left = 0.0
	if walk:
		_x = DOOR_X
		_state = State.ENTERING
		view.start_act(VIEW_SCRIPT.Act.WALK)
		view.walk_dir = 1
	else:
		_x = HOME_X
		_state = State.HERE
		_schedule_act()


## 방을 나간다. walk 면 왼쪽 가장자리로 걸어 나가는 걸 기다린다
func leave(walk: bool) -> void:
	if _state == State.OUT:
		return
	view.stop_act()
	_walk_left = 0.0
	if not walk:
		_go_out()
		return
	_state = State.LEAVING
	view.start_act(VIEW_SCRIPT.Act.WALK)
	view.walk_dir = -1
	await left_room


func is_present() -> bool:
	return _state != State.OUT


## 지금 서 있는 자리. 방 좌표다. 부르기가 대화 모드의 방에 같은 자리로 세운다
func room_x() -> float:
	return _x


## 부르기가 끝난 자리로 옮겨 선다. 대화 안에서 트렁크까지 걸어갔다면 거기 남는다
func place(x: float) -> void:
	if x < 0.0 or _state != State.HERE:
		return
	_x = clampf(x, WALK_MIN_X, WALK_MAX_X)


## 쪽지가 꽂혔다. 수첩을 꺼내 적는다. 다른 일을 하는 중이면 생략한다(시메지와 같다)
func write() -> void:
	if _state != State.HERE or paused or view.is_acting():
		return
	view.start_act(VIEW_SCRIPT.Act.WRITE)


func _go_out() -> void:
	view.stop_act()
	view.visible = false
	_state = State.OUT
	left_room.emit()


func _process(delta: float) -> void:
	if room != null:
		view.position = Vector2(_x, room.size.y * room.floor_ratio)
	match _state:
		State.ENTERING:
			if _step_toward(HOME_X, DOOR_SPEED * delta):
				view.stop_act()
				_state = State.HERE
		State.LEAVING:
			if _step_toward(DOOR_X, DOOR_SPEED * delta):
				_go_out()
		State.HERE:
			_tick_act(delta)


## to 까지 한 걸음. 다 왔으면 참
func _step_toward(to: float, step: float) -> bool:
	if absf(to - _x) <= step:
		_x = to
		return true
	_x += signf(to - _x) * step
	return false


# ── 자기 일. 종류는 시메지와 같다 ──

func _schedule_act() -> void:
	var gap := ACT_GAP_DEBUG if OS.is_debug_build() else ACT_GAP_RELEASE
	_act_wait = randf_range(gap.x, gap.y)
	_walk_left = 0.0


func _tick_act(delta: float) -> void:
	if view.is_acting():
		if _walk_left > 0.0:
			_tick_walk(delta)
		return
	if paused:
		return
	_act_wait -= delta
	if _act_wait > 0.0:
		return
	var kinds := [VIEW_SCRIPT.Act.READ, VIEW_SCRIPT.Act.WALK, VIEW_SCRIPT.Act.BURY]
	var pick: int = kinds[randi() % kinds.size()]
	view.start_act(pick)
	if pick == VIEW_SCRIPT.Act.WALK:
		var span := WALK_TIME_DEBUG if OS.is_debug_build() else WALK_TIME_RELEASE
		_walk_left = randf_range(span.x, span.y)
		view.walk_dir = 1 if randf() < 0.5 else -1


## 방 안 걷기. 범위 끝에 닿으면 방향을 바꾼다
func _tick_walk(delta: float) -> void:
	_walk_left -= delta
	if _walk_left <= 0.0 or paused:
		view.stop_act()
		return
	_x += view.walk_dir * WALK_SPEED * delta
	if _x <= WALK_MIN_X:
		_x = WALK_MIN_X
		view.walk_dir = 1
	elif _x >= WALK_MAX_X:
		_x = WALK_MAX_X
		view.walk_dir = -1
