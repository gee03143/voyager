extends Node2D

## 헤이즐이 걸치고 드는 것 — 앞치마, 수첩, 연필. 도형 임시 소품이다.
## 헤이즐 노드의 자식으로 붙어 리그 계약(발바닥 원점, 위가 음수)의 좌표와 배율을 탄다.

enum Book { NONE, HELD, RAISED, OPEN }

const C_LINE := Color("#2A2320")
const C_PAPER := Color("#FFFDF4")
const C_COVER := Color("#3C4A5C")

var apron := false :
	set(v):
		apron = v
		queue_redraw()
var book := Book.NONE :
	set(v):
		book = v
		queue_redraw()
var pencil := false :
	set(v):
		pencil = v
		queue_redraw()


func _draw() -> void:
	if apron:
		draw_line(Vector2(-15, -58), Vector2(-22, -74), C_LINE, 2.0)   # 끈
		draw_line(Vector2(15, -58), Vector2(22, -74), C_LINE, 2.0)
		draw_rect(Rect2(-17, -58, 34, 42), Color("#F3EEE4"))
		draw_rect(Rect2(-17, -58, 34, 42), C_LINE, false, 2.0)
	match book:
		Book.HELD:                                                     # 품에 안는다
			_notebook(Rect2(-6, -54, 18, 24))
		Book.RAISED:                                                   # 들어 보인다
			_notebook(Rect2(24, -104, 20, 26))
		Book.OPEN:                                                     # 펼쳐 보인다
			for r in [Rect2(10, -106, 22, 28), Rect2(32, -106, 22, 28)]:
				draw_rect(r, C_PAPER)
				draw_rect(r, C_LINE, false, 1.5)
	if pencil:
		draw_line(Vector2(56, -74), Vector2(44, -98), C_LINE, 5.0)
		draw_line(Vector2(56, -74), Vector2(45, -96), Color("#E2B34A"), 3.0)
		draw_circle(Vector2(44, -98), 1.8, C_LINE)                     # 심


func _notebook(r: Rect2) -> void:
	draw_rect(r, C_COVER)
	draw_rect(r, C_LINE, false, 1.5)
