extends HBoxContainer

const DAY_NAMES := ["월", "화", "수", "목", "금", "토", "일"]
const AXIS_STEP := 2.0 * 3600.0
const PLAY_COLOR := Color("e8dcc4")

@onready var _max_label: Label = $YAxisLabels/MaxLabel
@onready var _mid_label: Label = $YAxisLabels/MidLabel
@onready var _chart: BarChart = $ChartCol/Chart
@onready var _day_labels: HBoxContainer = $ChartCol/DayLabels

func _ready() -> void:
	for n in DAY_NAMES:
		var lbl := Label.new()
		lbl.text = n
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_day_labels.add_child(lbl)
	_chart.resized.connect(_update_axis_positions)
	Save.activity_log.changed.connect(_refresh)
	_refresh()

func _update_axis_positions() -> void:
	_max_label.position = Vector2(0, -_max_label.size.y * 0.5)
	_mid_label.position = Vector2(0, _chart.size.y * 0.5 - _mid_label.size.y * 0.5)
	
func _update_axis_labels() -> void:
	_max_label.text = DateUtil.format_hours(_chart.axis_max)
	_mid_label.text = DateUtil.format_hours(_chart.axis_max * 0.5)

func _refresh() -> void:
	var monday := DateUtil.monday_iso()
	var values: Array[float] = []
	for i in 7:
		var iso := DateUtil.add_days(monday, i)
		values.append(float(Save.activity_log.play_days.get(iso, 0.0)))
	_chart.series = [{"values": values, "color": PLAY_COLOR}]
	_chart.axis_max = _compute_axis_max(values)
	_update_axis_labels()

func _compute_axis_max(values: Array[float]) -> float:
	var peak := 0.0
	for v in values:
		peak = maxf(peak, v)
	return maxf(ceilf(peak / AXIS_STEP), 1.0) * AXIS_STEP
