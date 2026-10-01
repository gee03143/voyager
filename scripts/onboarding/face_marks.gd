extends Node2D

## 얼굴 위에 얹는 홍조와 땀방울. 리그에는 없는 표시라 쓰는 쪽이 헤이즐 노드의 자식으로 붙인다.
## 좌표는 리그 계약(발바닥 원점, 위가 음수)을 따르고 헤이즐 배율을 그대로 탄다.
## 머리 기울기는 따라가지 않는다(docs/architecture/companion-rig.md 의 "표정").

const C_BLUSH := Color(0.93, 0.45, 0.45, 0.55)
const C_SWEAT := Color("#A9D2EC")
const C_LINE := Color("#2A2320")

var blush := false :
	set(v):
		blush = v
		queue_redraw()
var sweat := false :
	set(v):
		sweat = v
		queue_redraw()


func _draw() -> void:
	if blush:
		for x in [-21.0, 21.0]:
			draw_set_transform(Vector2(x, -93), 0.0, Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, 7.0, C_BLUSH)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if sweat:
		var c := Vector2(34, -122)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(-5, 0), c + Vector2(5, 0)]), C_SWEAT)
		draw_circle(c, 5.0, C_SWEAT)
		draw_arc(c, 5.0, 0.0, PI, 10, C_LINE, 1.2)
