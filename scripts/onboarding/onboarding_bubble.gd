extends Control

## 헤이즐의 말풍선. 지금 하는 말 하나만 담고, 왼쪽 위에 이름표가 걸린다.
## 꼬리 끝은 tail_x 로 받는다 — 말풍선이 화면 가장자리에 밀려도 꼬리는 헤이즐을 가리킨다.
## 규격은 docs/specs/onboarding.md 의 "줄"과 docs/companion-persona.md §8.

const PAD := 16.0
const TAIL := 14.0
const MAX_W := 560.0
const C_TX := Color("#221F1A")
const C_LINE := Color("#2A2320")
const C_TAG_TX := Color("#F3EEE4")
const C_FILL := Color(1, 1, 1, 0.97)

var label: Label
var tag: PanelContainer
var tail_x := 0.0
var _tag_label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 숨긴 글자도 줄바꿈 계산에 넣는다. 안 그러면 찍히는 동안 줄이 다시 접힌다(docs/architecture/ui-animation.md)
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	label.add_theme_color_override("font_color", C_TX)
	label.add_theme_font_size_override("font_size", 20)
	label.position = Vector2(PAD, PAD)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	tag = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_LINE
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	tag.add_theme_stylebox_override("panel", sb)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_label = Label.new()
	_tag_label.add_theme_color_override("font_color", C_TAG_TX)
	_tag_label.add_theme_font_size_override("font_size", 15)
	tag.add_child(_tag_label)
	add_child(tag)
	set_speaker("???")


func set_speaker(s: String) -> void:
	_tag_label.text = s
	tag.size = tag.get_combined_minimum_size()
	tag.position = Vector2(14, -tag.size.y + 6)
	tag.pivot_offset = tag.size * 0.5


## 글자를 0개 보이게 해두고 크기를 확정한다. 줄바꿈은 찍히는 동안 바뀌지 않는다.
## 폭은 폰트로 직접 잰다 — Label 의 최소 크기는 트리 밖에서 믿을 수 없었다
func set_text(t: String) -> void:
	label.text = t
	label.visible_characters = 0
	var font := label.get_theme_font("font")
	var fs := label.get_theme_font_size("font_size")
	var w := minf(font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0, MAX_W)
	w = maxf(w, tag.size.x + 20.0)
	var h := font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
	label.size = Vector2(w, h)
	size = Vector2(w + PAD * 2, h + PAD * 2)


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_FILL
	sb.set_corner_radius_all(14)
	sb.border_color = C_LINE
	sb.set_border_width_all(2)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var tx := clampf(tail_x, 24.0, size.x - 24.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(tx - 12, size.y - 2), Vector2(tx + 12, size.y - 2), Vector2(tail_x, size.y + TAIL)]),
		C_FILL)
