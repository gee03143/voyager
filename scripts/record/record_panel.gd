extends VBoxContainer

@onready var tab_nav: HBoxContainer = $TabNav
@onready var calendar = $Content/Host/ActivityTab/Calendar
@onready var view = $Content/Host/ActivityTab/RecordView
@onready var stats_tab: VBoxContainer = $Content/Host/StatsTab
@onready var _pages: Array = [$Content/Host/ActivityTab, $Content/Host/StatsTab, $Content/Host/JournalTab]

var _nav := ButtonGroupNav.new()
var _day: String = ""
var _focus_label: Label
var _play_label: Label
var _haeri_label: Label
var _count_label: Label

func _ready() -> void:
	_build_stats()
	_nav.setup_from(tab_nav, false)                 # allow_close=false → 항상 하나 열림
	_nav.selected.connect(_on_tab_selected)
	calendar.day_selected.connect(_on_day_selected)
	Save.activity_log.changed.connect(_on_changed)
	Save.voyage.changed.connect(_refresh_stats)
	visibility_changed.connect(_on_visibility)
	_refresh_stats()
	_select_day(DateUtil.today_iso())
	_nav.select(0)                                  # 활동 탭 기본

func _on_tab_selected(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = (i == index)

func _on_day_selected(iso: String) -> void:
	_day = iso
	view.render_day(iso)

func _on_changed() -> void:
	calendar.refresh()
	_refresh_stats()
	if _day != "":
		view.render_day(_day)                       # 새 이벤트 반영해 현재 날짜 다시 그림

func _on_visibility() -> void:
	if visible:
		calendar.refresh()
		_refresh_stats()
		_select_day(DateUtil.today_iso())           # 열 때 오늘로

func _select_day(iso: String) -> void:
	_day = iso
	calendar.set_selected(iso)
	view.render_day(iso)

func _build_stats() -> void:
	_focus_label = _add_stat()
	_play_label = _add_stat()
	_haeri_label = _add_stat()
	_count_label = _add_stat()

func _add_stat() -> Label:
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_tab.add_child(l)
	return l

func _refresh_stats() -> void:
	var v := Save.voyage
	_focus_label.text = "누적 집중: %s" % _fmt_hm(int(v.total_focus_seconds))
	_play_label.text = "누적 플레이: %s" % _fmt_hm(int(v.total_play_seconds))
	_haeri_label.text = "항해 거리: %.1f leagues" % v.voyage_distance
	_count_label.text = "총 활동: %d건" % Save.activity_log.events.size()
	# TODO : 업적 전시

func _fmt_hm(total: int) -> String:
	return "%dh %02dm" % [total / 3600, (total % 3600) / 60]
