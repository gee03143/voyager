class_name Shelf
extends Node2D

signal pressed

@export var hide_offset := Vector2(400, 0)   # 숨김=보임 위치 + 이 오프셋(화면 밖으로). 방향/거리 튜닝용
@export var slide_decay := 6.0               # 클수록 빨리 붙음(이징 속도)

@onready var _area: Area2D = $Area2D
@onready var _badge: Label = $Badge

var _shown_pos := Vector2.ZERO

func _ready() -> void:
	_shown_pos = position                     # 에디터 배치 위치 = 보일 위치
	position = _shown_pos + hide_offset        # 시작 = 화면 밖(숨김)
	_area.input_event.connect(_on_area_input)
	set_badge(0)

func _process(delta: float) -> void:
	var docked := not Clock.is_focusing()      # 정박(휴식) = 비집중
	var target := _shown_pos if docked else _shown_pos + hide_offset
	position = position.lerp(target, 1.0 - exp(-slide_decay * delta))   # 프레임 독립 이징
	_area.input_pickable = docked              # 정박 중에만 클릭 가능

func set_badge(count: int) -> void:
	_badge.visible = count > 0
	if count > 0:
		_badge.text = "받은 편지 %d" % count

func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
