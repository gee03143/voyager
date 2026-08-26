class_name TimelineBlock
extends PanelContainer

signal selected(event_id: int)

@onready var label: Label = $Label

var _event_id: int = 0
var _accent := Color.GRAY
var _approx := false
var _sb: StyleBoxFlat = null

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func setup(text: String, accent: Color, approx: bool, clip_top := false, clip_bottom := false, event_id: int = 0) -> void:
	_event_id = event_id
	_accent = accent
	_approx = approx
	var base := get_theme_stylebox("panel")
	var sb: StyleBoxFlat = base.duplicate() if base is StyleBoxFlat else StyleBoxFlat.new()
	sb.bg_color = Color(accent, 0.08 if approx else 0.16)
	sb.border_color = Color(accent, 0.30 if approx else 0.55)
	if clip_top:                      # 시작이 전날 — 위로 이어진다는 표시
		sb.corner_radius_top_left = 0
		sb.corner_radius_top_right = 0
	if clip_bottom:                   # 끝이 다음날
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
	add_theme_stylebox_override("panel", sb)
	_sb = sb
	label.text = text

func set_selected(on: bool) -> void:
	if _sb == null:
		return
	_sb.bg_color = Color(_accent, 0.34 if on else (0.08 if _approx else 0.16))
	_sb.border_color = Color(_accent, 0.90 if on else (0.30 if _approx else 0.55))

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _event_id != 0:
		selected.emit(_event_id)
		accept_event()
