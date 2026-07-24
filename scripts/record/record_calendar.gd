extends VBoxContainer

signal day_selected(iso: String)

const HEAT_LOW := Color("4caf50")    # 활동 적음 = 연한 초록
const HEAT_HIGH := Color("114415ff")   # 활동 많음 = 진한 초록

@onready var _month_label: Label = $Nav/MonthLabel
@onready var _header: GridContainer = $Header
@onready var _grid: GridContainer = $Grid
@onready var _prev_button: Button = $Nav/PrevButton
@onready var _next_button: Button = $Nav/NextButton
@onready var _today_button: Button = $Nav/TodayButton

var _year: int
var _month: int
var _selected: String = ""
var _counts: Dictionary = {}     # {iso: 활동 수}

func _ready() -> void:
	var t := Time.get_date_dict_from_system()
	_year = t.year
	_month = t.month
	_prev_button.pressed.connect(_prev_month)
	_next_button.pressed.connect(_next_month)
	_today_button.pressed.connect(_go_today)
	_today_button.text = TranslationServer.translate("DATE_TODAY")
	for i in DateUtil.DAY_NAME_KEYS.size():
		(_header.get_child(i) as Label).text = TranslationServer.translate(DateUtil.DAY_NAME_KEYS[i])
	refresh()

func refresh() -> void:                 # 활동 수 재집계 + 다시 그림
	_recount()
	_render_month()

func set_selected(iso: String) -> void: # 패널이 선택일 동기화(신호 없이)
	_selected = iso
	var p := iso.split("-")
	if p.size() == 3 and (int(p[0]) != _year or int(p[1]) != _month):
		_year = int(p[0]); _month = int(p[1])
	_render_month()

func _recount() -> void:
	_counts = {}
	for e in Save.activity_log.events:
		var iso := DateUtil.local_day_iso(int(e.get("ts", 0)))
		_counts[iso] = int(_counts.get(iso, 0)) + 1
	var has := {}
	for d in Save.habit_defs:
		has[int(d["id"])] = true
	for wk in Save.habit_weeks:
		var ws := str(wk.get("week_start", ""))
		var checks: Dictionary = wk.get("checks", {})
		for k in checks:
			if not has.has(int(k)):
				continue
			var arr = checks[k]
			for di in 7:
				if di < arr.size() and bool(arr[di]):
					var iso := DateUtil.add_days(ws, di)
					_counts[iso] = int(_counts.get(iso, 0)) + 1

func _render_month() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_month_label.text = DateUtil.month_label("%04d-%02d-01" % [_year, _month])
	for slot in DateUtil.month_grid("%04d-%02d-01" % [_year, _month]):
		if slot.is_empty():
			_grid.add_child(_blank())
		else:
			_grid.add_child(_day_cell(slot, int(slot.split("-")[2])))

func _day_cell(iso: String, day: int) -> Control:
	var b := Button.new()
	b.text = str(day)
	b.custom_minimum_size = Vector2(32, 32)
	var sb := StyleBoxFlat.new()
	var cnt := int(_counts.get(iso, 0))  # TODO: 집중 시간, 플레이 시간으로도 판단 가능하게 수정
	if cnt > 0:
		var t := clampf((cnt - 1) / 5.0, 0.0, 1.0)  # 6건 이상이면 최대한 진하게
		sb.bg_color = HEAT_LOW.lerp(HEAT_HIGH, t)
	else:
		sb.bg_color = Color(1, 1, 1, 0.05)        # 빈 날 옅은 셀
	if iso == _selected:
		sb.set_border_width_all(2)
		sb.border_color = Color("ffd54a")          # 선택 강조(노란 테두리) — 배경색은 유지
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func():
		_selected = iso
		_render_month()
		day_selected.emit(iso))
	return b

func _blank() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(32, 32)
	return c

func _prev_month() -> void:
	_month -= 1
	if _month < 1: _month = 12; _year -= 1
	_render_month()

func _next_month() -> void:
	_month += 1
	if _month > 12: _month = 1; _year += 1
	_render_month()

func _go_today() -> void:
	var t := Time.get_date_dict_from_system()
	_year = t.year; _month = t.month
	_render_month()
