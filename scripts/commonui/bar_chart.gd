class_name BarChart
extends Control

const GRID_COLOR := Color(0.16470589, 0.14901961, 0.12156863, 0.10)   # 잉크 10%
const BAR_GAP := 0.2    # 막대 사이 여백 비율(칸 너비 대비)

# 막대마다 노드가 없어 노드 속성에 트윈을 걸 수 없다. 경과 시간 하나를 트윈하고
# _draw()가 칸마다 제 진행률을 계산한다(docs/specs/ui-animation.md 그래프 막대).
#
# 속도는 고정이다. 축 끝까지 채우는 시간이 기준이라 절반 높이는 절반이 걸리고,
# 먼저 시작한 막대가 먼저 끝나지 않는다. 픽셀이 아니라 축 높이 비율이 기준이라
# 창 크기가 연출 길이를 바꾸지 않는다. F6에서 눈으로 맞춘 값.
const RISE_SEC := 0.35
const STAGGER_SEC := 0.04           # 칸 간 시작 지연
const STAGGER_WINDOW_MAX := 0.45    # 마지막 칸이 시작하기까지의 상한. 칸이 많은 월 모드에서만 걸린다

var series: Array[Dictionary] = []:   # [{values: Array[float], color: Color}, ...]
	set(v):
		series = v
		queue_redraw()
var axis_max: float = 1.0:
	set(v):
		axis_max = maxf(v, 0.001)
		queue_redraw()

var _elapsed := 0.0     # play_fill 이후 지난 시간. 칸마다 여기서 제 시작 시각을 빼 진행률을 낸다
var _filling := false
var _tween: Tween

# 값을 세팅하는 것과 차오르는 것은 별개다. 조작에 대한 응답일 때만 부른다.
# 차오르는 중에 다시 부르면 버리고 처음부터 다시 차오른다 — 축 최대값이 매번 다시 잡히므로
# 지금 높이의 의미가 달라져 이어갈 수 없다.
func play_fill(delay: float = 0.0) -> void:
	_kill()
	var total := _fill_duration()
	if total <= 0.0:
		settle()
		return
	_elapsed = 0.0
	_filling = true
	queue_redraw()
	# 감속을 걸지 않는다. 속도가 고정이라는 것이 이 연출의 핵심이다.
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)   # 기다리는 동안 막대는 비어 있다. 다 그렸다가 다시 차오르지 않게
	_tween.tween_method(_set_elapsed, 0.0, total, total)
	_tween.finished.connect(_on_fill_finished)

# 진행 중인 차오름을 버리고 최종 모습으로 그린다.
func settle() -> void:
	_kill()
	_filling = false
	queue_redraw()

func _set_elapsed(v: float) -> void:
	_elapsed = v
	queue_redraw()

func _on_fill_finished() -> void:
	_tween = null
	_filling = false
	queue_redraw()

func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func _column_count() -> int:
	if series.is_empty():
		return 0
	return (series[0]["values"] as Array).size()

# 칸 수가 모드마다 다르다. 시작 구간이 상한을 넘으면 그 안으로 압축한다.
func _stagger(n: int) -> float:
	if n <= 1:
		return 0.0
	return minf(STAGGER_SEC, STAGGER_WINDOW_MAX / float(n - 1))

func _ratio(value: float) -> float:
	return clampf(value / axis_max, 0.0, 1.0)

# 가장 늦게 끝나는 막대에 맞춘다. 먼저 시작한 칸이 먼저 끝나는 게 아니라 계산이 필요하다.
func _fill_duration() -> float:
	var n := _column_count()
	if n == 0:
		return 0.0
	var stagger := _stagger(n)
	var last_end := 0.0
	for i in n:
		var col_peak := 0.0
		for s in series:
			var values: Array = s["values"]
			if i < values.size():
				col_peak = maxf(col_peak, _ratio(float(values[i])))
		if col_peak > 0.0:
			last_end = maxf(last_end, stagger * float(i) + col_peak * RISE_SEC)
	return last_end

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
	var s_count := series.size()
	var bar_area_w := col_w * (1.0 - BAR_GAP)
	var bar_w := bar_area_w / s_count
	var stagger := _stagger(n)
	for i in n:
		var col_x := col_w * i + col_w * BAR_GAP * 0.5
		# 이 칸이 지금까지 올라온 높이(축 비율). 아직 시작 전이면 0이다.
		var grown := maxf(_elapsed - stagger * float(i), 0.0) / RISE_SEC
		for si in s_count:
			var values: Array = series[si]["values"]
			var color: Color = series[si]["color"]
			var v := _ratio(float(values[i]))
			if _filling:
				v = minf(v, grown)
			if v <= 0.0:
				continue
			var h := size.y * v
			var x := col_x + bar_w * si
			draw_rect(Rect2(x, size.y - h, bar_w, h), color)
