class_name RadialProgress
extends Control

@export var arc_color: Color = Color(0.4, 0.7, 1.0)
@export var track_color: Color = Color(1, 1, 1, 0.15)
@export var arc_width: float = 3.0
@export var track_ticks: int = 0        # 0 = 매끈한 트랙, >0 = 눈금 베젤

var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - arc_width
	if radius <= 0.0:
		return
	if track_ticks > 0:
		var tw := maxf(1.0, arc_width * 0.35)
		for i in track_ticks:
			var frac := float(i) / track_ticks
			var ang := TAU * frac - PI / 2                       # 12시부터 시계방향
			var dir := Vector2(cos(ang), sin(ang))
			var c := arc_color if frac < value else track_color  # 남은 구간 = 채움
			draw_line(center + dir * (radius - arc_width * 1.2), center + dir * radius, c, tw)
	else:
		draw_arc(center, radius, 0.0, TAU, 64, track_color, arc_width, true)
		if value > 0.0:
			draw_arc(center, radius, -PI / 2, -PI / 2 + TAU * value, 64, arc_color, arc_width, true)
