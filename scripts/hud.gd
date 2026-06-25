extends PanelContainer

const ICON_PAUSE := preload("res://assets/placeholder/pause.svg")
const ICON_PLAY := preload("res://assets/placeholder/play.svg")

@onready var _handle: Control = $Margin/VBox/Handle
@onready var _grip: Control = $Margin/VBox/GripRow/Grip
@onready var _ring: RadialProgress = $Margin/VBox/RingBox/Ring
@onready var _time_label: Label = $Margin/VBox/RingBox/TimeLabel
@onready var _caption: Label = $Margin/VBox/CaptionRow/Caption
@onready var _timeline: SegmentTimeline = $Margin/VBox/Timeline
@onready var _pause_button: Button = $Margin/VBox/Buttons/PauseButton
@onready var _skip_button: Button = $Margin/VBox/Buttons/SkipButton
@onready var _reset_button: Button = $Margin/VBox/Buttons/ResetButton

var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_pos := Vector2.ZERO

var _resizing := false
var _resize_start_mouse := Vector2.ZERO
var _resize_start_scale := 1.0

func _ready() -> void:
	_pause_button.pressed.connect(Clock.active_toggle)
	_skip_button.pressed.connect(Clock.active_skip)
	_reset_button.pressed.connect(Clock.active_reset)
	
	Clock.pomodoro.running_changed.connect(_refresh)
	Clock.pomodoro.segment_changed.connect(func(_i: int): _refresh())
	Clock.pomodoro.session_completed.connect(_refresh)
	Clock.timer.running_changed.connect(_refresh)
	Clock.timer.timer_finished.connect(_refresh)
	
	_handle.gui_input.connect(_on_handle_input)
	set_anchors_preset(Control.PRESET_TOP_LEFT)     # 자유 위치 기준점 = 좌상단
	position = _initial_pos()
	
	pivot_offset_ratio = Vector2.ZERO                    # 좌상단 기준 스케일(위치 고정)
	scale = Vector2(Save.settings.hud_scale, Save.settings.hud_scale)   # 저장된 크기 적용
	_grip.gui_input.connect(_on_grip_input)
	
	_refresh()

func _process(_delta: float) -> void:
	if not Clock.is_active():
		visible = false
		return
	visible = true
	var total := Clock.active_total()
	_ring.value = (Clock.active_time_left() / total) if total > 0.0 else 0.0
	_time_label.text = _format(Clock.active_time_left())

func _refresh() -> void:
	visible = Clock.is_active()
	if not visible:
		return
	_pause_button.icon = ICON_PLAY if Clock.active_paused() else ICON_PAUSE
	_skip_button.visible = Clock.active_kind() == Clock.Kind.POMODORO
	_caption.text = _caption_text()
	_update_timeline()
	
func _update_timeline() -> void:
	if Clock.active_kind() == Clock.Kind.POMODORO:
		var p: Pomodoro = Clock.pomodoro
		_timeline.visible = true
		_timeline.render(p.segment_types, p.index, p.finished)
	else:
		_timeline.visible = false

func _format(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%02d:%02d" % [s / 60, s % 60]

func _caption_text() -> String:
	match Clock.active_kind():
		Clock.Kind.POMODORO:
			return _pomo_caption()
		Clock.Kind.TIMER:
			return "타이머"
	return ""

func _pomo_caption() -> String:
	var p: Pomodoro = Clock.pomodoro
	var type := p.segment_type_at(p.index)
	if type == Pomodoro.SegmentType.FOCUS:
		return "%s %d / %d" % [Pomodoro.type_name(type), _focus_number(p), p.total_focus_count]
	return Pomodoro.type_name(type)        # 휴식 단계면 단계명

func _focus_number(p: Pomodoro) -> int:
	var n := 0
	for i in range(p.index + 1):
		if p.segment_type_at(i) == Pomodoro.SegmentType.FOCUS:
			n += 1
	return n
	
func _initial_pos() -> Vector2:
	if Save.settings.hud_position != Vector2(-1, -1):
		return Save.settings.hud_position
	var vp := get_viewport_rect().size
	return Vector2(vp.x * 0.6, 24.0)                # 기본: 중앙에서 약간 우상단

func _on_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_drag_start_mouse = get_global_mouse_position()
			_drag_start_pos = position
		else:
			Save.settings.hud_position = position      # 놓을 때 저장
			Save.settings.changed.emit()
	elif event is InputEventMouseMotion and _dragging:
		position = _drag_start_pos + (get_global_mouse_position() - _drag_start_mouse)
		
func _on_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_resizing = true
			_resize_start_mouse = get_global_mouse_position()
			_resize_start_scale = scale.x
		else:
			_resizing = false
			Save.settings.hud_scale = scale.x          # 놓을 때 저장
			Save.settings.changed.emit()
	elif event is InputEventMouseMotion and _resizing:
		var delta := get_global_mouse_position() - _resize_start_mouse
		var base := size.x + size.y                    # 미스케일 기준 크기
		if base > 0.0:
			var s := clampf(_resize_start_scale + (delta.x + delta.y) / base, 0.6, 2.0)
			scale = Vector2(s, s)
