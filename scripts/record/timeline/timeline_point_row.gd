class_name TimelinePointRow
extends HBoxContainer

@onready var time_label: Label = $TimeLabel
@onready var dot: Panel = $Dot
@onready var text_label: Label = $TextLabel

func setup(time_text: String, accent: Color, text: String) -> void:
	time_label.text = time_text
	text_label.text = text
	var base := dot.get_theme_stylebox("panel")
	var sb: StyleBoxFlat = base.duplicate() if base is StyleBoxFlat else StyleBoxFlat.new()
	sb.bg_color = accent
	dot.add_theme_stylebox_override("panel", sb)
