extends Control

## 쪽지를 방 벽에 꽂은 압정. 쪽지(PanelContainer)의 자식으로 붙어 쪽지 크기에 맞춰지고, 위 가운데에 점 하나만 그린다.
## 쪽지는 컨테이너 안이라 기울일 수 없다(docs/architecture/ui-animation.md) — 꽂힌 느낌은 압정과 그림자로 낸다.

const C_TACK := Color("#C0563F")
const C_SHINE := Color(1, 1, 1, 0.55)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := Vector2(size.x * 0.5, 1.0)
	draw_circle(c, 5.5, C_TACK)
	draw_circle(c + Vector2(-1.6, -1.6), 1.6, C_SHINE)
