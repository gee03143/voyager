extends VBoxContainer

const MODE_LABELS := ["FullScreen", "Borderless Windowed", "Windowed"]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const FPS_FOCUSED := [30, 60, 0]     # 0 = 무제한(Vsync = true이므로 모니터 주사율에 맞춰짐), Vsync = false는 앱 성격 상 불필요할듯
const FPS_UNFOCUSED := [5, 10, 15, 30]

@onready var mode_option: OptionButton = $WindowModeRow/WindowModeOption
@onready var res_option: OptionButton = $ResolutionRow/ResolutionOption
@onready var fps_focused_option: OptionButton = $FpsFocusedRow/FpsFocusedOption
@onready var fps_unfocused_option: OptionButton = $FpsUnfocusedRow/FpsUnfocusedOption
@onready var hud_reset_button: Button = $HudResetButton
@onready var on_top_check: CheckButton = $AlwaysOnTopRow/AlwaysOnTopCheck

func _ready() -> void:
	mode_option.clear()
	for label in MODE_LABELS:
		mode_option.add_item(label)
	mode_option.select(Save.settings.window_mode)
	mode_option.item_selected.connect(_on_mode)
	
	res_option.clear()
	for r in RESOLUTIONS:
		res_option.add_item("%d × %d" % [r.x, r.y])
	_select_current_resolution()
	res_option.item_selected.connect(_on_resolution)

	_init_fps_option(fps_focused_option, FPS_FOCUSED, Save.settings.fps_focused)
	fps_focused_option.item_selected.connect(_on_fps_focused)
	_init_fps_option(fps_unfocused_option, FPS_UNFOCUSED, Save.settings.fps_unfocused)
	fps_unfocused_option.item_selected.connect(_on_fps_unfocused)

	hud_reset_button.pressed.connect(_on_hud_reset)

	on_top_check.button_pressed = Save.settings.always_on_top
	on_top_check.toggled.connect(_on_always_on_top)

	_update_res_enabled()

func _on_mode(idx: int) -> void:
	Save.settings.window_mode = idx
	Screen.apply_window_mode()
	Save.settings.changed.emit()
	
func _on_resolution(idx: int) -> void:
	Save.settings.window_size = RESOLUTIONS[idx]
	Screen.apply_window_size()
	Save.settings.changed.emit()

func _select_current_resolution() -> void:
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == Save.settings.window_size:
			res_option.select(i)
			return    # 목록에 없으면 미선택(-1) — 다음 선택 시 반영

func _update_res_enabled() -> void:
	res_option.disabled = (Save.settings.window_mode != Screen.Mode.WINDOWED)
	
func _init_fps_option(opt: OptionButton, values: Array, current: int) -> void:
	opt.clear()
	for v in values:
		opt.add_item("무제한" if v == 0 else "%d FPS" % v)
	for i in values.size():
		if values[i] == current:
			opt.select(i)
			return
	
func _on_fps_focused(idx: int) -> void:
	Save.settings.fps_focused = FPS_FOCUSED[idx]
	Screen.apply_fps(true)               # 옵션 조작 중 = 포커스 상태 → 즉시 반영
	Save.settings.changed.emit()

func _on_fps_unfocused(idx: int) -> void:
	Save.settings.fps_unfocused = FPS_UNFOCUSED[idx]
	Save.settings.changed.emit()         # 다음 포커스 아웃 때 적용

func _on_hud_reset() -> void:
	Save.settings.hud_position = Vector2(-1, -1)
	Save.settings.hud_scale = 1.0
	Save.settings.hud_reset.emit()      # HUD 라이브 복원 (hud.gd가 _apply_hud_geometry 실행)
	Save.settings.changed.emit()        # 저장
	
func _on_always_on_top(on: bool) -> void:
	Save.settings.always_on_top = on
	Screen.apply_always_on_top()
	Save.settings.changed.emit()
