extends Node

enum Mode { FULLSCREEN, BORDERLESS, WINDOWED }

func _ready() -> void:
	apply_window_mode()
	apply_fps(true)                          # 부팅 = 포커스 상태
	apply_always_on_top()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			apply_fps(true)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			apply_fps(false)

func apply_window_mode() -> void:
	match Save.settings.window_mode:
		Mode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		Mode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		Mode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			apply_window_size()
			
	apply_always_on_top()

func apply_window_size() -> void:
	if Save.settings.window_mode != Mode.WINDOWED:
		return
	var sz: Vector2i = Save.settings.window_size
	DisplayServer.window_set_size(sz)
	_center_window(sz)

func _center_window(sz: Vector2i) -> void:
	var idx := DisplayServer.window_get_current_screen()
	var rect := DisplayServer.screen_get_usable_rect(idx)
	DisplayServer.window_set_position(rect.position + (rect.size - sz) / 2)

func apply_fps(focused: bool) -> void:
	Engine.max_fps = Save.settings.fps_focused if focused else Save.settings.fps_unfocused

func apply_always_on_top() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, Save.settings.always_on_top)
