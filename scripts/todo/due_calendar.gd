class_name DueCalendar
extends VBoxContainer

signal day_selected(iso: String)

@onready var _month_label: Label = $Nav/MonthLabel
@onready var _prev_button: Button = $Nav/PrevButton
@onready var _next_button: Button = $Nav/NextButton
@onready var _today_button: Button = $Nav/TodayButton
@onready var _header: GridContainer = $Header
@onready var _grid: GridContainer = $Grid

var _year: int
var _month: int
var _selected: String = ""

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
	_update_separation()
	_render_month()

# 팝업이 열릴 때 현재 마감일로 동기화(신호 없이). 빈 값이면 오늘 달로.
func set_selected(iso: String) -> void:
	_selected = iso
	var t := Time.get_date_dict_from_system()
	_year = t.year; _month = t.month
	if not iso.is_empty():
		var p := iso.split("-")
		if p.size() == 3:
			_year = int(p[0]); _month = int(p[1])
	_update_separation()
	_render_month()

func _render_month() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_month_label.text = DateUtil.month_label("%04d-%02d-01" % [_year, _month])
	var today := DateUtil.today_iso()
	for slot in DateUtil.month_grid("%04d-%02d-01" % [_year, _month]):
		if slot.is_empty():
			_grid.add_child(_blank())
		else:
			_grid.add_child(_day_cell(slot, int(slot.split("-")[2]), slot == today))

func _day_cell(iso: String, day: int, is_today: bool) -> Control:
	var b := Button.new()
	b.text = str(day)
	b.custom_minimum_size = Vector2(32, 32)
	var sb: StyleBoxFlat
	if iso == _selected:
		sb = StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.12)
		sb.set_border_width_all(2)
		sb.border_color = Color("ffd54a")     # 선택됨 = 노란 테두리(기존)
	elif is_today:
		sb = StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.05)
		sb.set_border_width_all(1)
		sb.border_color = Color("7ec8ff")     # 오늘 = 옅은 파란 테두리(신규)
	if sb:
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

func _update_separation() -> void:
	var sep := maxi(int((size.x - 7 * 32) / 6.0), 2)
	_header.add_theme_constant_override("h_separation", sep)
	_grid.add_theme_constant_override("h_separation", sep)
