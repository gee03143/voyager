class_name RecordLogRow
extends HBoxContainer

@onready var badge: PanelContainer = $Badge
@onready var badge_label: Label = $Badge/BadgeLabel
@onready var text_label: Label = $TextLabel

func setup(type_key: String, accent: Color, text: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent, 0.18)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", sb)
	badge_label.text = TranslationServer.translate(type_key)
	badge_label.add_theme_color_override("font_color", accent)
	text_label.text = text
