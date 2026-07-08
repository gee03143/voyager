extends VBoxContainer

const DAY_NAMES := ["월", "화", "수", "목", "금", "토", "일"]
const AXIS_STEP := 2.0 * 3600.0
const PLAY_COLOR := Color("e8dcc4")
const FOCUS_COLOR := Color("8bc34a")

@onready var _mode_nav_container: HBoxContainer = $ModeNav
@onready var _period_nav: PeriodNav = $PeriodNav
@onready var _max_label: Label = $ChartRow/YAxisLabels/MaxLabel
@onready var _mid_label: Label = $ChartRow/YAxisLabels/MidLabel
@onready var _chart: BarChart = $ChartRow/ChartCol/Chart
@onready var _day_labels: HBoxContainer = $ChartRow/ChartCol/DayLabels
@onready var _play_swatch: ColorRect = $ChartRow/ChartCol/Legend/PlaySwatch
@onready var _focus_swatch: ColorRect = $ChartRow/ChartCol/Legend/FocusSwatch

var _mode_nav := ButtonGroupNav.new()

func _ready() -> void:
	_play_swatch.color = PLAY_COLOR
	_focus_swatch.color = FOCUS_COLOR
	_mode_nav.setup_from(_mode_nav_container, false)
	_mode_nav.selected.connect(_on_mode_selected)
	_mode_nav.select(0)
	_period_nav.refresh_requested.connect(func(): _refresh(_period_nav.current_start()))
	_chart.resized.connect(_update_axis_positions)
	Save.activity_log.changed.connect(func(): _refresh(_period_nav.current_start()))
	_refresh(_period_nav.current_start())

func _on_mode_selected(index: int) -> void:
	match index:
		1: _period_nav.set_unit(PeriodNav.Unit.MONTH)
		2: _period_nav.set_unit(PeriodNav.Unit.YEAR)
		_: _period_nav.set_unit(PeriodNav.Unit.WEEK)

func _update_axis_positions() -> void:
	_max_label.position = Vector2(0, -_max_label.size.y * 0.5)
	_mid_label.position = Vector2(0, _chart.size.y * 0.5 - _mid_label.size.y * 0.5)
	
func _update_axis_labels() -> void:
	_max_label.text = DateUtil.format_hours(_chart.axis_max)
	_mid_label.text = DateUtil.format_hours(_chart.axis_max * 0.5)

func _refresh(start: String) -> void:
	if _period_nav.unit == PeriodNav.Unit.YEAR:
		_refresh_year(start)
	else:
		_refresh_days(start)

func _refresh_days(start: String) -> void:
	var days := _days_for(start)
	_rebuild_day_labels(days)
	var play_values: Array[float] = []
	for iso in days:
		play_values.append(float(Save.activity_log.play_days.get(iso, 0.0)))
	_apply_series(play_values, _focus_seconds_for(days))

func _refresh_year(start: String) -> void:
	var year := int(start.split("-")[0])
	_rebuild_month_labels()
	var play_values: Array[float] = []
	play_values.resize(12)
	play_values.fill(0.0)
	for iso in Save.activity_log.play_days:
		var p := str(iso).split("-")
		if int(p[0]) == year:
			play_values[int(p[1]) - 1] += float(Save.activity_log.play_days[iso])
	_apply_series(play_values, _focus_seconds_for_months(year))

func _apply_series(play_values: Array[float], focus_values: Array[float]) -> void:
	_chart.series = [
		{"values": play_values, "color": PLAY_COLOR},
		{"values": focus_values, "color": FOCUS_COLOR},
	]
	_chart.axis_max = _compute_axis_max(play_values + focus_values)
	_update_axis_labels()	

func _days_for(start: String) -> Array[String]:
	var count := DateUtil.days_in_month(start) if _period_nav.unit == PeriodNav.Unit.MONTH else 7
	var days: Array[String] = []
	for i in count:
		days.append(DateUtil.add_days(start, i))
	return days

func _rebuild_month_labels() -> void:
	for c in _day_labels.get_children():
		c.queue_free()
	for m in 12:
		var lbl := Label.new()
		lbl.text = str(m + 1)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_day_labels.add_child(lbl)

func _rebuild_day_labels(days: Array[String]) -> void:
	for c in _day_labels.get_children():
		c.queue_free()
	var use_day_number := _period_nav.unit == PeriodNav.Unit.MONTH
	for i in days.size():
		var lbl := Label.new()
		lbl.text = str(i + 1) if use_day_number else DAY_NAMES[i]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_day_labels.add_child(lbl)

func _focus_seconds_for(days: Array[String]) -> Array[float]:
	var totals: Array[float] = []
	totals.resize(days.size())
	totals.fill(0.0)
	for e in Save.activity_log.events:
		var type := str(e.get("type", ""))
		if type != "pomodoro_session" and type != "timer":
			continue
		var idx := days.find(DateUtil.local_day_iso(int(e.get("ts", 0))))
		if idx != -1:
			totals[idx] += float(e.get("seconds", 0))
	return totals

func _focus_seconds_for_months(year: int) -> Array[float]:
	var totals: Array[float] = []
	totals.resize(12)
	totals.fill(0.0)
	for e in Save.activity_log.events:
		var type := str(e.get("type", ""))
		if type != "pomodoro_session" and type != "timer":
			continue
		var p := DateUtil.local_day_iso(int(e.get("ts", 0))).split("-")
		if int(p[0]) == year:
			totals[int(p[1]) - 1] += float(e.get("seconds", 0))
	return totals

func _compute_axis_max(values: Array[float]) -> float:
	var peak := 0.0
	for v in values:
		peak = maxf(peak, v)
	return maxf(ceilf(peak / AXIS_STEP), 1.0) * AXIS_STEP
