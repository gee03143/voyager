extends Node

enum Mode { FULLSCREEN, BORDERLESS, WINDOWED }

const COMPANION_SIZE := Vector2i(280, 200)

var _pre_companion_window_mode: int = Mode.WINDOWED
var _pre_content_scale_size: Vector2i = Vector2i(0, 0)

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

func enter_companion() -> void:
	_pre_companion_window_mode = Save.settings.window_mode
	_pre_content_scale_size = get_tree().root.content_scale_size

	DisplayServer.window_set_min_size(Vector2i(0, 0))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	get_window().transparent = true
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	DisplayServer.window_set_size(COMPANION_SIZE)
	get_tree().root.content_scale_size = COMPANION_SIZE
	_restore_companion_position()

func exit_companion() -> void:
	_save_companion_position()

	get_window().transparent = false
	RenderingServer.set_default_clear_color(Color(0.1, 0.1, 0.1, 1))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	get_tree().root.content_scale_size = _pre_content_scale_size

	match _pre_companion_window_mode:
		Mode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		Mode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Save.settings.window_size)
			_center_window(Save.settings.window_size)
	apply_always_on_top()

func _restore_companion_position() -> void:
	var pos := Save.settings.companion_position
	if pos == Vector2i(-1, -1):
		var idx := DisplayServer.window_get_current_screen()
		var rect := DisplayServer.screen_get_usable_rect(idx)
		pos = Vector2i(
			rect.position.x + rect.size.x - COMPANION_SIZE.x - 20,
			rect.position.y + rect.size.y - COMPANION_SIZE.y - 60
		)
	DisplayServer.window_set_position(pos)

func _save_companion_position() -> void:
	Save.settings.companion_position = DisplayServer.window_get_position()
	Save.settings.changed.emit()
