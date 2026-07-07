class_name BarChart
extends Control

const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.15)
const BAR_GAP := 0.2    # 막대 사이 여백 비율(칸 너비 대비)

var series: Array[Dictionary] = []:   # [{values: Array[float], color: Color}, ...]
	set(v):
		series = v
		queue_redraw()
var axis_max: float = 1.0:
	set(v):
		axis_max = maxf(v, 0.001)
		queue_redraw()

func _draw() -> void:
	if series.is_empty():
		return
	var n: int = (series[0]["values"] as Array).size()
	if n == 0:
		return
	var col_w := size.x / n
	draw_line(Vector2(0, 0), Vector2(size.x, 0), GRID_COLOR, 1.0)
	draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), GRID_COLOR, 1.0)
	draw_line(Vector2(0, size.y), Vector2(size.x, size.y), GRID_COLOR, 1.0)
	for s in series:                      # 슬라이스2 = 1계열. 2계열(슬라이스4)부터는 칸 안 나눠서 그려야 함
		var values: Array = s["values"]
		var color: Color = s["color"]
		for i in n:
			var v := clampf(float(values[i]) / axis_max, 0.0, 1.0)
			if v <= 0.0:
				continue
			var h := size.y * v
			var w := col_w * (1.0 - BAR_GAP)
			var x := col_w * i + col_w * BAR_GAP * 0.5
			draw_rect(Rect2(x, size.y - h, w, h), color)
