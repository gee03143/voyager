extends Node2D

## 헤이즐의 트렁크. 도형 임시 소품이다(docs/architecture/companion-rig.md 의 임시 파츠 원칙).
## 원점은 바닥 중앙이다. 헤이즐과 같은 배율을 주면 자기 몸만 하게 보인다.

const W := 118.0
const H := 104.0
const C_LINE := Color("#2A2320")

var opened := false :
	set(v):
		opened = v
		queue_redraw()


func _draw() -> void:
	draw_body(self)
	if opened:
		draw_rect(Rect2(-W * 0.5, -H - 60, W, 54), Color("#6A3F26"))   # 열린 뚜껑
		draw_rect(Rect2(-W * 0.5, -H - 60, W, 54), C_LINE, false, 4.0)
		draw_rect(Rect2(-W * 0.5 + 8, -H + 6, W - 16, 30), Color("#2E1E14"))
		draw_rect(Rect2(-44, -H + 2, 40, 22), Color("#F3EEE4"))         # 접힌 앞치마
		draw_rect(Rect2(2, -H - 2, 26, 30), Color("#3C4A5C"))           # 닳은 수첩
		for i in 3:
			draw_circle(Vector2(38 + i * 7, -H + 16 - i * 3), 6, Color("#C88A4A"))   # 도토리


## 닫힌 몸통. 헤이즐의 방(hazel_room.gd)도 같은 트렁크를 줄여 그린다. 원점은 바닥 중앙
static func draw_body(ci: CanvasItem) -> void:
	var body := Rect2(-W * 0.5, -H, W, H)
	ci.draw_rect(body, Color("#7B4B2E"))
	ci.draw_rect(body, C_LINE, false, 4.0)
	for sx in [-W * 0.25, W * 0.25]:
		ci.draw_rect(Rect2(sx - 6, -H, 12, H), Color("#4E3020"))
	ci.draw_rect(Rect2(-18, -H - 12, 36, 12), Color("#4E3020"))          # 손잡이
	ci.draw_circle(Vector2(26, -H * 0.42), 11, Color("#C88A4A"))          # 도토리 스티커
	ci.draw_rect(Rect2(14, -H * 0.42 - 16, 24, 8), Color("#6B4426"))
