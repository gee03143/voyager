class_name TimelinePointRow
extends HBoxContainer

signal selected(event_id: int)

@onready var time_label: Label = $TimeLabel
@onready var dot: Panel = $Dot
@onready var text_label: Label = $TextLabel

var _event_id: int = 0
var _accent := Color.GRAY

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func setup(time_text: String, accent: Color, text: String, event_id: int = 0) -> void:
	time_label.text = time_text
	text_label.text = text
	_event_id = event_id
	_accent = accent
	var base := dot.get_theme_stylebox("panel")
	var sb: StyleBoxFlat = base.duplicate() if base is StyleBoxFlat else StyleBoxFlat.new()
	sb.bg_color = accent
	dot.add_theme_stylebox_override("panel", sb)

func set_selected(on: bool) -> void:
	if on:
		text_label.add_theme_color_override("font_color", _accent)
	else:
		text_label.remove_theme_color_override("font_color")

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _event_id != 0:
		selected.emit(_event_id)
		accept_event()
