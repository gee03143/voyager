extends Node2D

@onready var _parallax: ParallaxBackground = $Parallax
@onready var _ship: Sprite2D = $Ship
@onready var _ring: RadialProgress = $UI/Root/RingBox/Ring
@onready var _time_label: Label = $UI/Root/RingBox/TimeLabel
@onready var _caption: Label = $UI/Root/Caption
@onready var _return_btn: Button = $UI/Root/ReturnButton
@onready var _drag_bar: Control = $UI/Root/DragBar

const PX_PER_NMI := 60.0
const CRUISE_SPEED := 1.0
const ACCEL := 0.6
const BOB_AMP := 2.0
const BOB_FREQ := 2.0
const ROCK_AMP := 0.02

var _ship_base_y := 0.0
var _bob_t := 0.0
var _ship_speed := 0.0

var _dragging := false
var _drag_start_mouse := Vector2i.ZERO
var _drag_start_window := Vector2i.ZERO

func _ready() -> void:
	_ship_base_y = _ship.position.y
	_return_btn.pressed.connect(_on_return)
	_drag_bar.gui_input.connect(_on_drag_input)
	Clock.pomodoro.running_changed.connect(_refresh)
	Clock.pomodoro.segment_changed.connect(func(_i: int): _refresh())
	Clock.pomodoro.session_completed.connect(_on_session_completed)
	Clock.timer.timer_finished.connect(_on_session_completed)
	Clock.timer.running_changed.connect(_refresh)
	_refresh()

func _process(delta: float) -> void:
	var target := CRUISE_SPEED if Clock.is_focusing() else 0.0
	_ship_speed = move_toward(_ship_speed, target, ACCEL * delta)
	if _ship_speed > 0.0:
		Save.voyage.voyage_distance += _ship_speed * delta
	var d := Save.voyage.voyage_distance * PX_PER_NMI
	for layer in _parallax.get_children():
		if layer is ParallaxLayer and layer.motion_mirroring.x > 0.0:
			layer.motion_offset.x = -fmod(d * layer.motion_scale.x, layer.motion_mirroring.x)
	_bob_t += delta
	var rough := 1.0 + _ship_speed * 0.6
	_ship.position.y = _ship_base_y + sin(_bob_t * BOB_FREQ) * BOB_AMP * rough
	_ship.rotation = sin(_bob_t * BOB_FREQ * 0.5) * ROCK_AMP

	if Clock.is_active():
		var total := Clock.active_total()
		_ring.value = (Clock.active_time_left() / total) if total > 0.0 else 0.0
		_time_label.text = _fmt(Clock.active_time_left())

func _refresh() -> void:
	var active := Clock.is_active()
	_ring.visible = active
	_time_label.visible = active
	_caption.visible = active
	if not active:
		return
	_caption.text = _caption_text()

func _on_return() -> void:
	Screen.exit_companion()
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start_mouse = DisplayServer.mouse_get_position()
			_drag_start_window = DisplayServer.window_get_position()
		else:
			_dragging = false
			Save.settings.companion_position = DisplayServer.window_get_position()
			Save.settings.changed.emit()
	elif event is InputEventMouseMotion and _dragging:
		var delta := DisplayServer.mouse_get_position() - _drag_start_mouse
		DisplayServer.window_set_position(_drag_start_window + delta)
		
func _on_session_completed() -> void:
	_refresh()
	if Save.settings.auto_exit_companion:
		_on_return()
		
func _fmt(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%02d:%02d" % [s / 60, s % 60]

func _caption_text() -> String:
	match Clock.active_kind():
		Clock.Kind.POMODORO:
			var p: Pomodoro = Clock.pomodoro
			return Pomodoro.type_name(p.segment_type_at(p.index))
		Clock.Kind.TIMER:
			return "타이머"
	return ""
