extends Node2D

## 앱의 루트. 시메지가 주 창이고 다이어리 셸이 자식 창이다.
##
## 이 순서인 이유는 하나다 — 자식 창은 hide 하면 작업표시줄에서도 사라지지만
## 주 창은 OS 가 앱의 대표 창으로 잡고 있어 그렇게 되지 않는다.
## 대가로 Screen autoload 가 주 창 대신 셸 창을 가리켜야 한다(Screen.bind_shell).

const VIEW_SCRIPT := preload("res://scripts/companion/shimeji_view.gd")
const MAIN_SHELL := preload("res://scenes/MainShell.tscn")

const WIN_SIZE := Vector2i(280, 340)
const FOOT_MARGIN := 40              # 발바닥이 창 아래에서 이만큼 위에 선다
const SCREEN_MARGIN := Vector2i(80, 120)
const DRAG_SLOP := 3                 # 이만큼 안 움직였으면 끈 게 아니라 누른 것으로 본다
const FOOT_LINE := WIN_SIZE.y - FOOT_MARGIN   # 창 안에서 발바닥이 놓인 높이
const GRAVITY := 2000.0
const FOREHEAD_EXIT_MARGIN := 12.0   # 이마를 이만큼 벗어나야 들기로 넘어간다

enum Press { NONE, PETTING, DRAGGING }

## 자기 일 사이의 간격. spec 초안값은 하루 3~5회라 F6 로는 확인이 안 된다.
## 그래서 디버그 실행에서만 짧게 준다. 내보낸 빌드는 진짜 간격으로 돈다.
const ACT_GAP_RELEASE := Vector2(14400.0, 28800.0)   # 4~8시간
const ACT_GAP_DEBUG := Vector2(8.0, 18.0)
const WALK_SPEED := 46.0                             # 초당 픽셀
const WALK_TIME_RELEASE := Vector2(12.0, 25.0)
const WALK_TIME_DEBUG := Vector2(7.0, 12.0)
const MENU_QUIT_ID := 100

## 우클릭 메뉴. 값은 NavList 순서이고 0 이 홈이다.
const MENU_ITEMS := [
	{"key": "HOME_BUTTON", "nav": 0},
	{"key": "TODO_BUTTON", "nav": 1},
	{"key": "HABIT_BUTTON", "nav": 2},
	{"key": "TIMER_BUTTON", "nav": 3},
	{"key": "JOURNAL_BUTTON", "nav": 4},
	{"key": "RECORD_BUTTON", "nav": 5},
]

var _view: Node2D
var _shell: Window
var _main_shell: Node
var _menu: PopupMenu

var _press := Press.NONE
var _drag_offset := Vector2i.ZERO     # 커서에서 창 좌상단까지의 거리
var _press_at := Vector2i.ZERO
var _drag_moved := false
var _scruff_offset := Vector2i.ZERO   # 창 좌상단에서 목덜미까지

var _swing := 0.0
var _swing_v := 0.0
var _cursor_vx := 0.0
var _prev_mouse := Vector2i.ZERO
var _falling := false
var _fall_v := 0.0

var _act_wait := 0.0
var _walk_left := 0.0


func _ready() -> void:
	get_tree().root.gui_embed_subwindows = false   # 셸을 진짜 OS 창으로 띄운다
	_setup_root_window()
	_build_view()
	_build_shell()
	_build_menu()
	_view.act_finished.connect(_schedule_act)
	_schedule_act()


func _setup_root_window() -> void:
	var w := get_window()
	w.content_scale_size = WIN_SIZE                # 시메지는 1:1 로 그린다
	w.size = WIN_SIZE
	w.position = _restored_position()


## 저장된 자리가 지금 화면 밖이면 기본 자리로 돌아온다.
## 모니터를 뺐을 때 창이 안 보이는 데로 가는 것을 막는다.
func _restored_position() -> Vector2i:
	var saved: Vector2i = Save.settings.companion_position
	if saved == Vector2i(-1, -1):
		return _default_position()
	var center := saved + WIN_SIZE / 2
	for i in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_usable_rect(i).has_point(center):
			return saved
	return _default_position()


func _default_position() -> Vector2i:
	var rect := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	return rect.position + rect.size - WIN_SIZE - SCREEN_MARGIN


func _build_view() -> void:
	_view = VIEW_SCRIPT.new()
	_view.position = Vector2(WIN_SIZE.x * 0.5, FOOT_LINE)
	add_child(_view)
	_scruff_offset = Vector2i(_view.position + VIEW_SCRIPT.SCRUFF)


func _build_shell() -> void:
	_shell = Window.new()
	_shell.title = "Voyager"
	_shell.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_shell.size = Save.settings.window_size
	_main_shell = MAIN_SHELL.instantiate()
	_shell.add_child(_main_shell)
	add_child(_shell)
	_shell.close_requested.connect(_shell.hide)    # 닫기는 숨기기다. 앱은 안 끝난다
	Screen.bind_shell(_shell)


func _build_menu() -> void:
	_menu = PopupMenu.new()
	for item in MENU_ITEMS:
		_menu.add_item(tr(item["key"]), item["nav"])
	_menu.add_separator()
	_menu.add_item(tr("SHIMEJI_MENU_QUIT"), MENU_QUIT_ID)
	_menu.id_pressed.connect(_on_menu_id)
	add_child(_menu)


func _on_menu_id(id: int) -> void:
	if id == MENU_QUIT_ID:
		get_tree().quit()
		return
	show_shell()
	if _main_shell != null and _main_shell.has_method("open_tool"):
		_main_shell.open_tool(id)


func show_shell() -> void:
	_shell.show()
	_shell.move_to_foreground()
	_shell.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _press != Press.NONE:
		_on_motion((event as InputEventMouseMotion).position)


func _on_motion(in_window: Vector2) -> void:
	if _press == Press.PETTING:
		# 이마를 벗어나면 쓰다듬기가 끝나고 들기로 넘어간다
		if _view.is_forehead(_view.to_local(in_window), FOREHEAD_EXIT_MARGIN):
			return
		_view.stop_pet()
		_press = Press.DRAGGING
		_drag_moved = false
		_press_at = DisplayServer.mouse_get_position()
	_drag_to(DisplayServer.mouse_get_position())


func _on_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		_open_menu()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_begin_press(mb.position)
	elif _press != Press.NONE:
		_end_press()


## 누른 자리로 갈린다. 이마면 쓰다듬기, 그 밖이면 들기 준비다.
## 창 좌표는 커서 전역 좌표에서 구한다 —
## 이벤트의 로컬 좌표를 쓰면 창이 움직이는 동안 기준이 같이 흔들린다.
func _begin_press(in_window: Vector2) -> void:
	_drag_moved = false
	_press_at = DisplayServer.mouse_get_position()
	_drag_offset = get_window().position - _press_at
	if _view.is_forehead(_view.to_local(in_window)):
		_press = Press.PETTING
		_view.start_pet()
	else:
		_press = Press.DRAGGING


func _drag_to(mouse: Vector2i) -> void:
	if not _drag_moved:
		if _press_at.distance_to(mouse) <= DRAG_SLOP:
			return
		# 끌기로 판정되는 순간 목덜미를 커서에 붙인다. 잡힌 자세가 되는 지점이다
		_drag_moved = true
		_drag_offset = -_scruff_offset
		_swing = 0.0
		_swing_v = 0.0
		_cursor_vx = 0.0
		_prev_mouse = mouse
		_view.lift()
	get_window().position = mouse + _drag_offset


func _end_press() -> void:
	var was := _press
	_press = Press.NONE
	if was == Press.PETTING:
		_view.stop_pet()
		_schedule_act()
		return
	if not _drag_moved:
		return                         # 이마 밖을 끌지 않고 누른 것은 아무 일도 아니다
	var target_y := _ground_y() - FOOT_LINE
	if get_window().position.y < target_y:
		_falling = true                # 높은 자리에서 놓았으면 떨어진다
		_fall_v = 0.0
	else:
		_finish_landing()


func _finish_landing() -> void:
	_view.land()
	_save_position()


## 발바닥이 닿는 높이. 작업표시줄을 뺀 영역의 아래끝이다
func _ground_y() -> int:
	return DisplayServer.screen_get_usable_rect(get_window().current_screen).end.y


func _process(delta: float) -> void:
	if _press == Press.DRAGGING and _drag_moved:
		_tick_swing(delta, false)
	elif _falling:
		_tick_swing(delta, true)
		_tick_fall(delta)
	_tick_act(delta)


## 다음 자기 일까지의 대기. 행동이 끝날 때마다 다시 잡는다
func _schedule_act() -> void:
	var gap := ACT_GAP_DEBUG if OS.is_debug_build() else ACT_GAP_RELEASE
	_act_wait = randf_range(gap.x, gap.y)
	_walk_left = 0.0


func _tick_act(delta: float) -> void:
	if _view.is_acting():
		if _walk_left > 0.0:
			_tick_walk(delta)
		return
	if _press != Press.NONE or _falling:
		return                      # 만지는 중에는 자기 일을 시작하지 않는다
	_act_wait -= delta
	if _act_wait > 0.0:
		return
	_start_random_act()


func _start_random_act() -> void:
	var kinds := [VIEW_SCRIPT.Act.READ, VIEW_SCRIPT.Act.WALK, VIEW_SCRIPT.Act.BURY]
	var pick: int = kinds[randi() % kinds.size()]
	_view.start_act(pick)
	if pick == VIEW_SCRIPT.Act.WALK:
		var span := WALK_TIME_DEBUG if OS.is_debug_build() else WALK_TIME_RELEASE
		_walk_left = randf_range(span.x, span.y)
		_view.walk_dir = 1 if randf() < 0.5 else -1


## 걷기만 창을 옮긴다. 화면 가장자리에 닿으면 방향을 바꾼다
func _tick_walk(delta: float) -> void:
	_walk_left -= delta
	if _walk_left <= 0.0:
		_view.stop_act()
		return
	var w := get_window()
	var rect := DisplayServer.screen_get_usable_rect(w.current_screen)
	var p := w.position
	p.x += int(round(_view.walk_dir * WALK_SPEED * delta))
	var left := rect.position.x
	var right := rect.end.x - WIN_SIZE.x
	if p.x <= left:
		p.x = left
		_view.walk_dir = 1
	elif p.x >= right:
		p.x = right
		_view.walk_dir = -1
	w.position = p


## 커서의 가로 속도를 목표 각도로 바꾼 뒤 스프링으로 따라간다.
## 속도를 가속도에 직접 더하면 정상상태 각도가 스프링 계수로 나뉘어 거의 안 보인다.
func _tick_swing(delta: float, settling: bool) -> void:
	var target := 0.0
	if not settling:
		var m := DisplayServer.mouse_get_position()
		var raw := float(m.x - _prev_mouse.x) / maxf(delta, 0.001)
		_prev_mouse = m
		_cursor_vx += (raw - _cursor_vx) * minf(delta * 16.0, 1.0)
		target = clampf(-_cursor_vx * 0.05, -44.0, 44.0)
	_swing_v += ((target - _swing) * 70.0 - _swing_v * 7.0) * delta
	_swing += _swing_v * delta
	_swing = clampf(_swing, -58.0, 58.0)
	_view.swing = _swing


func _tick_fall(delta: float) -> void:
	_fall_v += GRAVITY * delta
	var w := get_window()
	var p := w.position
	var target_y := _ground_y() - FOOT_LINE
	p.y += int(_fall_v * delta)
	if p.y >= target_y:
		p.y = target_y
		w.position = p
		_falling = false
		_finish_landing()
		return
	w.position = p


func _save_position() -> void:
	Save.settings.companion_position = get_window().position
	Save.settings.changed.emit()       # 전역 설정은 save-on-change


func _open_menu() -> void:
	var at := DisplayServer.mouse_get_position()
	_menu.popup(Rect2i(at, Vector2i.ZERO))
