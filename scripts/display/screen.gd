extends Node

## 창 설정 적용. 대상은 주 창이 아니라 **다이어리 셸 창**이다.
##
## 루트 창은 시메지이고 셸은 그 자식 창이다(docs/specs/shimeji.md).
## 그래서 여기서는 DisplayServer 의 암묵적 주 창 대신 bind_shell 로 받은 Window 를 만진다.

enum Mode { FULLSCREEN, BORDERLESS, WINDOWED }

const SHELL_MIN_SIZE := Vector2i(850, 600)
## 시메지가 늘 화면에 있으므로 비포커스라도 이 아래로 내리지 않는다.
## fps_unfocused 는 "안 보일 때 아끼자"는 설정이었는데 그 전제가 사라졌다.
const SHIMEJI_MIN_FPS := 30

var _shell: Window = null


func _ready() -> void:
	apply_fps(true)                          # 부팅 = 포커스 상태


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			apply_fps(true)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			apply_fps(false)


## 셸 창이 만들어진 뒤 루트가 한 번 불러준다.
func bind_shell(window: Window) -> void:
	_shell = window
	_shell.min_size = SHELL_MIN_SIZE
	apply_window_mode()


func apply_window_mode() -> void:
	if _shell == null:
		return
	match Save.settings.window_mode:
		Mode.FULLSCREEN:
			_shell.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		Mode.BORDERLESS:
			_shell.mode = Window.MODE_FULLSCREEN
		_:
			_shell.mode = Window.MODE_WINDOWED
			apply_window_size()
	apply_always_on_top()


func apply_window_size() -> void:
	if _shell == null or Save.settings.window_mode != Mode.WINDOWED:
		return
	_shell.size = Save.settings.window_size
	_center()


func _center() -> void:
	var rect := DisplayServer.screen_get_usable_rect(_shell.current_screen)
	_shell.position = rect.position + (rect.size - _shell.size) / 2


func apply_fps(focused: bool) -> void:
	if focused:
		Engine.max_fps = Save.settings.fps_focused
	else:
		Engine.max_fps = maxi(Save.settings.fps_unfocused, SHIMEJI_MIN_FPS)


func apply_always_on_top() -> void:
	if _shell == null:
		return
	_shell.always_on_top = Save.settings.always_on_top


# --- 폐기 예정 ---
# 옛 always-on-top 미니 모드의 진입/복귀. 시메지가 그 역할을 가져갔다.
# world.gd / companion_mode.gd 가 아직 부르고 있어 호출부를 정리할 때까지 남긴다.

func enter_companion() -> void:
	push_warning("Screen.enter_companion 은 시메지로 대체됐다")


func exit_companion() -> void:
	push_warning("Screen.exit_companion 은 시메지로 대체됐다")
