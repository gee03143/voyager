extends VBoxContainer

const DAY_NAMES := ["월", "화", "수", "목", "금", "토", "일"]
const AXIS_STEP := 2.0 * 3600.0
const PLAY_COLOR := Color("e8dcc4")
const FOCUS_COLOR := Color("8bc34a")

@onready var _period_nav: PeriodNav = $PeriodNav
@onready var _max_label: Label = $ChartRow/YAxisLabels/MaxLabel
@onready var _mid_label: Label = $ChartRow/YAxisLabels/MidLabel
@onready var _chart: BarChart = $ChartRow/ChartCol/Chart
@onready var _day_labels: HBoxContainer = $ChartRow/ChartCol/DayLabels
@onready var _play_swatch: ColorRect = $ChartRow/ChartCol/Legend/PlaySwatch
@onready var _focus_swatch: ColorRect = $ChartRow/ChartCol/Legend/FocusSwatch

func _ready() -> void:
	for n in DAY_NAMES:
		var lbl := Label.new()
		lbl.text = n
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_day_labels.add_child(lbl)
	_play_swatch.color = PLAY_COLOR
	_focus_swatch.color = FOCUS_COLOR
	_period_nav.refresh_requested.connect(func(): _refresh(_period_nav.current_start()))
	_chart.resized.connect(_update_axis_positions)
	Save.activity_log.changed.connect(func(): _refresh(_period_nav.current_start()))
	_refresh(_period_nav.current_start())

func _update_axis_positions() -> void:
	_max_label.position = Vector2(0, -_max_label.size.y * 0.5)
	_mid_label.position = Vector2(0, _chart.size.y * 0.5 - _mid_label.size.y * 0.5)
	
func _update_axis_labels() -> void:
	_max_label.text = DateUtil.format_hours(_chart.axis_max)
	_mid_label.text = DateUtil.format_hours(_chart.axis_max * 0.5)

func _refresh(monday: String) -> void:
	var play_values: Array[float] = []
	for i in 7:
		var iso := DateUtil.add_days(monday, i)
		play_values.append(float(Save.activity_log.play_days.get(iso, 0.0)))
	var focus_values := _focus_seconds_for_week(monday)
	_chart.series = [
		{"values": play_values, "color": PLAY_COLOR},
		{"values": focus_values, "color": FOCUS_COLOR},
	]
	_chart.axis_max = _compute_axis_max(play_values + focus_values)
	_update_axis_labels()

func _focus_seconds_for_week(monday: String) -> Array[float]:
	var days: Array[String] = []
	for i in 7:
		days.append(DateUtil.add_days(monday, i))
	var totals: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for e in Save.activity_log.events:
		var type := str(e.get("type", ""))
		if type != "pomodoro_session" and type != "timer":
			continue
		var idx := days.find(DateUtil.local_day_iso(int(e.get("ts", 0))))
		if idx != -1:
			totals[idx] += float(e.get("seconds", 0))
	return totals

func _compute_axis_max(values: Array[float]) -> float:
	var peak := 0.0
	for v in values:
		peak = maxf(peak, v)
	return maxf(ceilf(peak / AXIS_STEP), 1.0) * AXIS_STEP
