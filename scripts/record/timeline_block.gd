class_name TimelineBlock
extends PanelContainer

@onready var label: Label = $Label

func setup(text: String, accent: Color, approx: bool, clip_top := false, clip_bottom := false) -> void:
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
	label.text = text
