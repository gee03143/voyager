class_name WidgetMover
extends Node

signal moved(position: Vector2)
signal resized(new_scale: float)

@export var target: Control
@export var drag_handle: Control
@export var resize_grip: Control
@export var min_scale: float = 0.6
@export var max_scale: float = 2.0

var _dragging := false
var _drag_start_mouse := Vector2.ZERO
var _drag_start_pos := Vector2.ZERO

var _resizing := false
var _resize_start_mouse := Vector2.ZERO
var _resize_start_scale := 1.0

func _ready() -> void:
	if target != null:
		target.pivot_offset_ratio = Vector2.ZERO
	if drag_handle != null:
		drag_handle.gui_input.connect(_on_drag_input)
	if resize_grip != null:
		resize_grip.gui_input.connect(_on_resize_input)

func _on_drag_input(event: InputEvent) -> void:
	if target == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_drag_start_mouse = target.get_global_mouse_position()
			_drag_start_pos = target.position
		else:
			moved.emit(target.position)
	elif event is InputEventMouseMotion and _dragging:
		target.position = _drag_start_pos + (target.get_global_mouse_position() - _drag_start_mouse)
		_clamp_to_screen()

func _on_resize_input(event: InputEvent) -> void:
	if target == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_resizing = true
			_resize_start_mouse = target.get_global_mouse_position()
			_resize_start_scale = target.scale.x
		else:
			_resizing = false
			resized.emit(target.scale.x)
	elif event is InputEventMouseMotion and _resizing:
		var delta := target.get_global_mouse_position() - _resize_start_mouse
		var base := target.size.x + target.size.y
		if base > 0.0:
			var s := clampf(_resize_start_scale + (delta.x + delta.y) / base, min_scale, max_scale)
			target.scale = Vector2(s, s)
			_clamp_to_screen()
			
func _clamp_to_screen() -> void:
	var vp := target.get_viewport_rect().size
	var ext := target.size * target.scale          # 화면상 크기(좌상단 피벗)
	target.position.x = clampf(target.position.x, 0.0, maxf(0.0, vp.x - ext.x))
	target.position.y = clampf(target.position.y, 0.0, maxf(0.0, vp.y - ext.y))
