class_name RadialProgress
extends Control

var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	if radius <= 0.0:
		return
	draw_arc(center, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.15), 3.0, true)         # 배경 링
	if value > 0.0:
		draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * value, 32, Color(0.4, 0.7, 1.0), 3.0, true)  # 달성 호(12시부터)
