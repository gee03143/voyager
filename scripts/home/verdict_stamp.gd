extends Control

## 홈의 판정 도장 하나(docs/specs/day-verdict.md 의 "계기 — 홈").
## 종류마다 글자 하나만 다르고 색·굵기·크기는 같다. 도장 사이에 위아래가 없어야 판정이 점수로 읽히지 않는다.
## 직접 적은 이름은 글자 대신 연필을 그린다. 이름과 날짜는 마우스를 올리면 보인다.

const SIZE := 44.0
const INK := Color("#3A3128")         # 쪽지의 헤이즐 글씨와 같은 잉크(companion_banner.gd 의 NOTE_INK)
const GLYPH_SIZE := 17
const MAX_TILT_DEG := 9.0             # 손으로 찍은 것처럼 조금씩 기운다

var glyph := ""                       # 비어 있으면 연필
var tilt := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)


## seed 는 판정의 id 다. 같은 판정은 다시 그려도 같은 각도로 기운다
func setup(glyph_text: String, tip: String, seed: int) -> void:
	glyph = glyph_text
	tooltip_text = tip
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	tilt = deg_to_rad(rng.randf_range(-MAX_TILT_DEG, MAX_TILT_DEG))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(size * 0.5, tilt, Vector2.ONE)
	var r := SIZE * 0.44
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(INK, 0.8), 2.0, true)
	draw_arc(Vector2.ZERO, r - 4.0, 0.0, TAU, 40, Color(INK, 0.45), 1.0, true)
	if glyph == "":
		_draw_pencil()
		return
	var font := get_theme_default_font()
	var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, GLYPH_SIZE).x
	var asc := font.get_ascent(GLYPH_SIZE)
	var desc := font.get_descent(GLYPH_SIZE)
	draw_string(font, Vector2(-w * 0.5, (asc - desc) * 0.5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, GLYPH_SIZE, Color(INK, 0.85))


## 직접 적은 이름. 비스듬한 연필 한 자루
func _draw_pencil() -> void:
	var c := Color(INK, 0.85)
	var a := Vector2(-7, 7)
	var b := Vector2(6, -6)
	draw_line(a, b, c, 4.0, true)
	draw_colored_polygon(PackedVector2Array([a + Vector2(-2.5, -2.5), a + Vector2(2.5, 2.5), a + Vector2(-4.5, 4.5)]), c)
