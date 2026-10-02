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
## 바탕화면에 있는가(docs/specs/settings.md 의 "내보내기"). 설정의 hazel_on_desktop 을 따라간다
enum Desk { HERE, LEAVING, AWAY, ARRIVING }

## 자기 일 사이의 간격. spec 초안값은 하루 3~5회라 F6 로는 확인이 안 된다.
## 그래서 디버그 실행에서만 짧게 준다. 내보낸 빌드는 진짜 간격으로 돈다.
# ⚠️ 간격과 걷기 시간은 방 안의 헤이즐(room_hazel.gd)에 같은 값이 옮겨 적혀 있다. 바꿀 때 같이 바꾼다
const ACT_GAP_RELEASE := Vector2(14400.0, 28800.0)   # 4~8시간
const ACT_GAP_DEBUG := Vector2(8.0, 18.0)
const WALK_SPEED := 46.0                             # 초당 픽셀
const WALK_TIME_RELEASE := Vector2(12.0, 25.0)
const WALK_TIME_DEBUG := Vector2(7.0, 12.0)
const MENU_QUIT_ID := 100
const AWAY_POS := Vector2i(-20000, -20000)           # 헤이즐이 방에 불려가 있는 동안의 창 자리. 모든 모니터 밖
## 클릭을 받는 영역. 발바닥 기준이다. 몸 전체를 덮어야 한다 — 영역 밖은 클릭뿐 아니라 그리기도 잘린다.
## 리그는 꼬리 끝 x ±63, 귀 끝 y −161 까지다(shimeji_view.gd / shimeji_part.gd). 조금 넉넉히 둔다
const HIT_BOX := Rect2(-70, -172, 140, 186)
const DESK_WALK_SPEED := 120.0                       # 나가고 들어오는 걸음. 평소 걷기보다 빠르다 — 떠나는 데 오래 걸리면 미련으로 읽힌다

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

var _desk := Desk.HERE
var _desk_x := 0.0                    # 나가고 들어오는 걸음의 창 x. 정수 자리로 반올림하면 느린 프레임에서 멈춘다
var _desk_to := 0.0
var _hit_clipped := false             # 창 영역을 HIT_BOX 로 잘라 두었는가
var _desk_walk := false               # 바탕화면 걸음이 준비됐다. 들어오기 전 방에서 걸어 나가는 동안은 거짓이다


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
	Save.settings.changed.connect(_reconcile_desk)
	_schedule_act()
	if onboarding:
		_start_onboarding()                     # 온보딩 동안은 설정과 상관없이 바탕화면에 있다. 끝나면 맞춘다
	elif not Save.settings.hazel_on_desktop:
		_set_away()                             # 내보낸 채로 켰다. 걸어 나가지 않고 처음부터 없다


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
	_reconcile_desk()


func _is_onboarding() -> bool:
	return _onboarding != null


# ── 헤이즐 부르기(docs/specs/hazel-room.md) ──

## 방을 눌렀다. 헤이즐은 한 번에 한 곳에만 있다 — 시메지를 거두고 셸의 대화 모드로 들어간다.
## 주 창은 숨길 수 없어 모든 모니터 밖으로 옮긴다(docs/architecture/transparent-window.md)
## verdict 면 홈에서 불렀다. 대화가 곧장 하루 판정으로 열린다(docs/specs/day-verdict.md)
## 바탕화면에서 내보낸 동안에도 부를 수 있다. 셸 안으로만 들어왔다 나간다
func _call_hazel(verdict := false) -> void:
	if _is_onboarding() or _call != null or _falling or _press != Press.NONE:
		return
	if _desk == Desk.LEAVING or _desk == Desk.ARRIVING:
		return                                  # 걷는 중이다. 한 번에 한 곳에만 있다
	var room_x := -1.0
	if _desk == Desk.HERE:
		_walk_left = 0.0
		_view.stop_act()
		var w := get_window()
		_call_from = w.position
		_view.visible = false
		w.position = AWAY_POS
	else:
		room_x = _room_hazel().room_x()         # 방 안에 있다. 그 자리에서 대화가 시작된다
		_room_hazel().paused = true
	_call = CALL_SCRIPT.new()
	add_child(_call)
	_call.ended.connect(_on_call_ended)
	_call.start(_shell, _main_shell, verdict, room_x)


## 대화가 끝났거나 셸이 닫혔다. 불려가기 직전 자리로 돌아와 내려앉는다
func _on_call_ended() -> void:
	var end_x: float = _call.end_room_x
	_call.queue_free()
	_call = null
	if _desk == Desk.AWAY:
		# 내보낸 동안 불렀다. 바탕화면으로 돌아오지 않고 방의 대화가 끝난 자리에 남는다
		var rh := _room_hazel()
		rh.place(end_x)
		rh.paused = false
		_reconcile_desk()
		return
	get_window().position = _call_from
	_view.visible = true
	_view.land()
	_schedule_act()


## 방에 쪽지가 꽂혔다. 바탕화면의 헤이즐이 수첩을 꺼내 적는다 — 몸과 쪽지가 이어진다.
## 다른 일을 하는 중이면(자기 일·만지기·떨어지기·자리 비움) 동작은 생략하고 쪽지만 꽂힌다
func _on_note_pinned() -> void:
	if _desk == Desk.AWAY and _call == null:
		_room_hazel().write()                   # 방 안에 있다. 그 자리에서 적는다
		return
	if _is_away() or _falling or _press != Press.NONE:
		return
	if _view.is_acting() or _view.pose != VIEW_SCRIPT.Pose.IDLE:
		return
	_view.start_act(VIEW_SCRIPT.Act.WRITE)


## 헤이즐이 바탕화면에 없다. 온보딩 중이거나, 방에 불려가 있거나, 내보냈거나 나가고 들어오는 중이다
func _is_away() -> bool:
	return _is_onboarding() or _call != null or _desk != Desk.HERE


# ── 내보내기·다시 부르기(docs/specs/settings.md 의 "내보내기") ──

## 설정과 지금 자리를 맞춘다. 걷는 중이면 그 걸음이 끝날 때 다시 불린다.
## 온보딩·부르기·만지기·떨어지기 중에도 미룬다 — 그것들이 끝나는 자리에서 다시 불린다
func _reconcile_desk() -> void:
	if _is_onboarding() or _call != null or _falling or _press != Press.NONE:
		return
	var want := Save.settings.hazel_on_desktop
	if _desk == Desk.HERE and not want:
		_start_leaving()
	elif _desk == Desk.AWAY and want:
		_start_arriving()


## 가장 가까운 화면 가장자리로 걸어가 밖으로 나간다. 말은 없다
func _start_leaving() -> void:
	_desk = Desk.LEAVING
	_view.stop_act()
	_walk_left = 0.0
	var w := get_window()
	var rect := DisplayServer.screen_get_usable_rect(w.current_screen)
	var center := w.position.x + WIN_SIZE.x * 0.5
	var dir := -1 if center - rect.position.x < rect.end.x - center else 1
	_desk_x = w.position.x
	_desk_to = rect.position.x - WIN_SIZE.x if dir < 0 else rect.end.x   # 창이 화면 밖으로 다 나가는 자리
	_desk_walk = true
	_view.start_act(VIEW_SCRIPT.Act.WALK)
	_view.walk_dir = dir


## 방에서 왼쪽으로 걸어 나간 뒤, 셸이 있는 화면의 오른쪽 아래 가장자리 밖에서 걸어 들어온다. 처음 왔던 쪽이다.
## 셸이 닫혀 있으면 방 쪽 걸음은 보이지 않으니 걷지 않는다
func _start_arriving() -> void:
	_desk = Desk.ARRIVING
	_desk_walk = false
	await _room_hazel().leave(_shell.visible)
	var w := get_window()
	w.current_screen = _shell.current_screen
	var rect := DisplayServer.screen_get_usable_rect(_shell.current_screen)
	_desk_x = rect.end.x
	_desk_to = rect.end.x - WIN_SIZE.x - SCREEN_MARGIN.x
	w.position = Vector2i(int(_desk_x), rect.end.y - FOOT_LINE)   # 발이 작업표시줄 위에 선다
	_view.visible = true
	_desk_walk = true
	_view.start_act(VIEW_SCRIPT.Act.WALK)
	_view.walk_dir = -1


func _tick_desk(delta: float) -> void:
	if not _desk_walk:
		return
	var dir := 1.0 if _desk_to > _desk_x else -1.0
	_desk_x += dir * DESK_WALK_SPEED * delta
	var done := (_desk_to - _desk_x) * dir <= 0.0
	if done:
		_desk_x = _desk_to
	var w := get_window()
	w.position = Vector2i(int(round(_desk_x)), w.position.y)
	if not done:
		return
	_view.stop_act()
	_desk_walk = false
	if _desk == Desk.LEAVING:
		_set_away(true)
	else:
		_desk = Desk.HERE
		_view.land()
		_save_position()
		_schedule_act()
	_reconcile_desk()                           # 걷는 동안 스위치가 또 바뀌었으면 지금 값으로 다시 맞춘다


## 바탕화면에 없는 상태로 둔다. 창은 모든 모니터 밖에 있다 — 주 창은 숨길 수 없다(docs/architecture/transparent-window.md).
## 헤이즐은 자기 방으로 들어간다. walk 면 셸이 보일 때 방 왼쪽에서 걸어 들어오고, 아니면 제자리에 바로 선다
func _set_away(walk := false) -> void:
	_desk = Desk.AWAY
	_view.stop_act()
	_walk_left = 0.0
	_view.visible = false
	get_window().position = AWAY_POS
	_room_hazel().enter(walk and _shell.visible)


func _room_hazel() -> Node2D:
	return _main_shell.room_hazel()


## 셸 닫기. 평소엔 숨기기고, 헤이즐을 내보낸 동안은 남는 창이 없으니 저장하고 끝낸다
func _on_shell_close() -> void:
	if _desk == Desk.AWAY or _desk == Desk.LEAVING:
		Save.quit_game()
		return
	_shell.hide()


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
	_shell.close_requested.connect(_on_shell_close)   # 닫기는 숨기기다. 앱은 안 끝난다 — 헤이즐을 내보낸 동안만 빼고
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
		Save.quit_game()                    # 밀린 쓰기·플레이 시간까지 저장하고 끝낸다. get_tree().quit() 는 저장을 건너뛴다
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
	_reconcile_desk()                           # 들고 있는 동안 스위치가 바뀌었을 수 있다


## 발바닥이 닿는 높이. 작업표시줄을 뺀 영역의 아래끝이다
func _ground_y() -> int:
	return DisplayServer.screen_get_usable_rect(get_window().current_screen).end.y


func _process(delta: float) -> void:
	if _press == Press.DRAGGING and _drag_moved:
		_tick_swing(delta, false)
	elif _falling:
		_tick_swing(delta, true)
		_tick_fall(delta)
	_tick_desk(delta)
	_tick_act(delta)
	_update_hit_area()


## 투명 창은 그려진 픽셀이 아니라 창 사각형 전체가 클릭을 받는다 — 엔진이 DwmEnableBlurBehindWindow 로만
## 투명을 만들고 픽셀 단위 판정을 하지 않는다(4.6 display_server_windows.cpp). 그래서 몸 둘레로 창 영역을 자른다.
## 들어 올려 흔드는 동안·떨어지는 동안은 몸이 상자를 벗어나므로 풀어 둔다. 온보딩은 창이 무대가 되므로 풀어 둔다
func _update_hit_area() -> void:
	var clip := not _is_onboarding() and not _falling and not (_press == Press.DRAGGING and _drag_moved)
	if clip == _hit_clipped:
		return
	_hit_clipped = clip
	if not clip:
		get_window().mouse_passthrough_polygon = PackedVector2Array()
		return
	var r := Rect2(_view.position + HIT_BOX.position, HIT_BOX.size)
	get_window().mouse_passthrough_polygon = PackedVector2Array([
		r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y),
	])


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
