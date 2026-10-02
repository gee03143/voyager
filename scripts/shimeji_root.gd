extends Node2D

## 앱의 루트. 시메지가 주 창이고 다이어리 셸이 자식 창이다.
##
## 이 순서인 이유는 하나다 — 자식 창은 hide 하면 작업표시줄에서도 사라지지만
## 주 창은 OS 가 앱의 대표 창으로 잡고 있어 그렇게 되지 않는다.
## 대가로 Screen autoload 가 주 창 대신 셸 창을 가리켜야 한다(Screen.bind_shell).

const VIEW_SCRIPT := preload("res://scripts/companion/shimeji_view.gd")
const MAIN_SHELL := preload("res://scenes/MainShell.tscn")
const ONBOARDING_SCRIPT := preload("res://scripts/onboarding/onboarding_player.gd")
const STAGE_SCRIPT := preload("res://scripts/onboarding/desktop_stage.gd")
const CALL_SCRIPT := preload("res://scripts/room/hazel_call.gd")
const CONSOLE_SCRIPT := preload("res://scripts/dev/dev_console.gd")

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
const AWAY_POS := Vector2i(-20000, -20000)           # 헤이즐이 방에 불려가 있는 동안의 창 자리. 모든 모니터 밖

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
var _onboarding: Node                 # 재생 중일 때만 있다
var _stage: Node2D                    # 온보딩 동안의 바탕화면 무대
var _call: Node                       # 헤이즐이 방에 불려가 있는 동안만 있다
var _call_from := Vector2i.ZERO       # 불려가기 직전의 창 자리. 걷기는 자리를 저장하지 않아 따로 기억한다

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
	var onboarding := not Save.settings.onboarded
	if onboarding:
		# 셸이 트리에 붙기 전에 멈춘다. 붙자마자 배너가 첫 문구를 찍으며 소리를 낸다
		_main_shell = MAIN_SHELL.instantiate()
		_main_shell.set_banner_suspended(true)
	_build_shell()
	_build_menu()
	if OS.is_debug_build():
		var console := CONSOLE_SCRIPT.new()     # 개발자 콘솔. 셸 창에서 F12(docs/specs/dev-console.md)
		add_child(console)
		console.setup(_shell)
	_main_shell.hazel_called.connect(_call_hazel)
	_main_shell.verdict_requested.connect(_call_hazel.bind(true))
	_main_shell.note_pinned.connect(_on_note_pinned)
	_view.act_finished.connect(_schedule_act)
	_schedule_act()
	if onboarding:
		_start_onboarding()


# ── 온보딩(docs/specs/onboarding.md) ──

## 온보딩 동안 이 창은 바탕화면 무대가 된다(desktop_stage.gd). 만지기·메뉴·자기 일은 멈춘다.
## 헤이즐이 셸 안에 있는 동안은 창을 숨기지 않고 헤이즐을 그리지 않는다 —
## 투명 창에 그려진 것이 없으면 비어 보이고 클릭도 통과한다
func _start_onboarding() -> void:
	_view.visible = false
	_stage = STAGE_SCRIPT.new()
	_stage.setup(_view, WIN_SIZE, FOOT_MARGIN)
	add_child(_stage)                     # 헤이즐 뒤에 붙어 트렁크·말풍선이 헤이즐 위에 그려진다
	_onboarding = ONBOARDING_SCRIPT.new()
	add_child(_onboarding)
	_onboarding.ended.connect(_on_onboarding_ended)
	_onboarding.start(_shell, _main_shell, _stage)


## 완료든 중단(셸 닫기)이든 헤이즐은 바탕화면으로 돌아온다. onboarded 는 완료일 때만 남긴다 —
## 중단이면 다음 실행에서 처음부터 다시 재생된다(docs/specs/onboarding.md 의 "중단")
func _on_onboarding_ended(completed: bool) -> void:
	_onboarding.queue_free()
	_onboarding = null
	remove_child(_stage)
	_stage.queue_free()
	_stage = null
	var w := get_window()
	w.size = WIN_SIZE
	w.content_scale_size = WIN_SIZE
	_view.position = Vector2(WIN_SIZE.x * 0.5, FOOT_LINE)
	_view.scale = Vector2.ONE
	_view.face = VIEW_SCRIPT.Face.NONE
	if completed:
		Save.settings.onboarded = true
		Save.settings.changed.emit()   # 전역 설정은 save-on-change
		_save_position()               # 5비트에서 헤이즐이 걸어간 자리가 곧 시메지 자리다
	else:
		# 셸 단계에서는 이 창이 모든 모니터 밖에 있다(desktop_stage.gd 의 close_stage). 그대로 기본 자리를 구하면
		# 엉뚱한 모니터가 잡힌다 — 셸이 있는 모니터로 먼저 옮겨두고 구한다
		w.current_screen = _shell.current_screen
		w.position = _restored_position()
	_main_shell.set_banner_suspended(false)
	_view.visible = true
	_schedule_act()


func _is_onboarding() -> bool:
	return _onboarding != null


# ── 헤이즐 부르기(docs/specs/hazel-room.md) ──

## 방을 눌렀다. 헤이즐은 한 번에 한 곳에만 있다 — 시메지를 거두고 셸의 대화 모드로 들어간다.
## 주 창은 숨길 수 없어 모든 모니터 밖으로 옮긴다(docs/architecture/transparent-window.md)
## verdict 면 홈에서 불렀다. 대화가 곧장 하루 판정으로 열린다(docs/specs/day-verdict.md)
func _call_hazel(verdict := false) -> void:
	if _is_away() or _falling or _press != Press.NONE:
		return
	_walk_left = 0.0
	_view.stop_act()
	var w := get_window()
	_call_from = w.position
	_view.visible = false
	w.position = AWAY_POS
	_call = CALL_SCRIPT.new()
	add_child(_call)
	_call.ended.connect(_on_call_ended)
	_call.start(_shell, _main_shell, verdict)


## 대화가 끝났거나 셸이 닫혔다. 불려가기 직전 자리로 돌아와 내려앉는다
func _on_call_ended() -> void:
	_call.queue_free()
	_call = null
	get_window().position = _call_from
	_view.visible = true
	_view.land()
	_schedule_act()


## 방에 쪽지가 꽂혔다. 바탕화면의 헤이즐이 수첩을 꺼내 적는다 — 몸과 쪽지가 이어진다.
## 다른 일을 하는 중이면(자기 일·만지기·떨어지기·자리 비움) 동작은 생략하고 쪽지만 꽂힌다
func _on_note_pinned() -> void:
	if _is_away() or _falling or _press != Press.NONE:
		return
	if _view.is_acting() or _view.pose != VIEW_SCRIPT.Pose.IDLE:
		return
	_view.start_act(VIEW_SCRIPT.Act.WRITE)


## 헤이즐이 바탕화면에 없다. 온보딩 중이거나 방에 불려가 있다
func _is_away() -> bool:
	return _is_onboarding() or _call != null


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
	if _main_shell == null:                        # 온보딩이면 미리 만들어 배너를 멈춰둔 것이 있다
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
	if _is_away():
		return                          # 만지기·우클릭 메뉴를 막는다. 온보딩 중 메뉴로 할 일 도구가 먼저 만들어지면 안 된다
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
	if _is_away():
		return
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
