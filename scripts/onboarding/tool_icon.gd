extends Control

## 4비트에서 트렁크에서 꺼내는 도구 하나. 도형 임시 소품이다.
## 꺼내면 셸 사이드바의 그 항목으로 날아가 스며든다.

enum Kind { NOTEBOOK, CARD, TIMER, DIARY, ACORNS }

const SIZE := 40.0
const C_LINE := Color("#2A2320")

var kind := Kind.NOTEBOOK


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(SIZE, SIZE)
	pivot_offset = size * 0.5


func _draw() -> void:
	match kind:
		Kind.NOTEBOOK:                                              # 닳은 수첩 — 할 일
			draw_rect(Rect2(8, 4, 24, 32), Color("#3C4A5C"))
			draw_rect(Rect2(8, 4, 24, 32), C_LINE, false, 2.0)
		Kind.CARD:                                                  # 작은 체크 카드 — 습관
			draw_rect(Rect2(4, 6, 32, 28), Color("#FFFDF4"))
			draw_rect(Rect2(4, 6, 32, 28), C_LINE, false, 2.0)
			for i in 3:
				var o := Vector2(9 + i * 9, 20)
				draw_polyline(PackedVector2Array([o, o + Vector2(2, 3), o + Vector2(6, -4)]), Color("#6E8B5A"), 2.0)
		Kind.TIMER:                                                 # 태엽 타이머 — 타이머
			draw_rect(Rect2(17, 4, 6, 6), C_LINE)
			draw_circle(Vector2(20, 23), 14, Color("#D9B25A"))
			draw_arc(Vector2(20, 23), 14, 0, TAU, 24, C_LINE, 2.0)
			draw_line(Vector2(20, 23), Vector2(20, 14), C_LINE, 2.0)
		Kind.DIARY:                                                 # 일기장 — 일지
			draw_rect(Rect2(6, 4, 28, 32), Color("#8A5A3C"))
			draw_rect(Rect2(6, 4, 28, 32), C_LINE, false, 2.0)
			draw_rect(Rect2(26, 4, 4, 18), Color("#B5654E"))
		Kind.ACORNS:                                                # 도토리 상자 — 기록
			draw_rect(Rect2(4, 20, 32, 16), Color("#7B4B2E"))
			draw_rect(Rect2(4, 20, 32, 16), C_LINE, false, 2.0)
			for i in 3:
				draw_circle(Vector2(12 + i * 8, 16 - (i % 2) * 3), 5, Color("#C88A4A"))
