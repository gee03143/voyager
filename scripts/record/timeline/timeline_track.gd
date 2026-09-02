class_name TimelineTrack
extends Control

const HOUR_PX := 60.0         # 1분 = 1px
const MIN_PX := HOUR_PX / 60.0
const GUTTER := 44.0          # 시각 라벨 열 폭

func _ready() -> void:
	custom_minimum_size.y = HOUR_PX * 24.0
	resized.connect(queue_redraw)

func _draw() -> void:
	var font := get_theme_default_font()
	var fs := 11
	var line_color := Color(0.16470589, 0.14901961, 0.12156863, 0.10)   # 잉크 10% — 24시간 눈금선
	var text_color := Color("9a9080")                                   # ink 3 — 시각 라벨
	for h in 25:
		var y := h * HOUR_PX
		draw_line(Vector2(GUTTER, y), Vector2(size.x, y), line_color, 1.0)
		if h < 24:
			draw_string(font, Vector2(0.0, y + fs + 2.0), "%02d:00" % h,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
