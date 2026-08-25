extends PanelContainer

@onready var tab_row: TabNavSlot = $Margin/Body/Main/TabRow
@onready var activity_panel: HBoxContainer = $Margin/Body/Main/ActivityPanel
@onready var graph_panel: Control = $Margin/Body/Main/GraphPanel
@onready var calendar = $Margin/Body/Main/ActivityPanel/Calendar
@onready var view = $Margin/Body/Main/ActivityPanel/Timeline
@onready var today_count_value: Label = $Margin/Body/Summary/SummaryMargin/SummaryVBox/TodayCountTile/Value
@onready var today_time_value: Label = $Margin/Body/Summary/SummaryMargin/SummaryVBox/TodayTimeTile/Value
@onready var total_focus_value: Label = $Margin/Body/Summary/SummaryMargin/SummaryVBox/TotalFocusTile/Value

var _day: String = ""

func _ready() -> void:
	tab_row.tab_selected.connect(_on_tab_selected)
	tab_row.set_tabs(["RECORD_TAB_ACTIVITY", "RECORD_TAB_GRAPH"])
	calendar.day_selected.connect(_on_day_selected)
	Save.activity_log.changed.connect(_on_activity_changed)
	if not has_meta("pooled"):
		on_shown()

func on_shown() -> void:
	_select_day(DateUtil.today_iso())
	_refresh_summary()

func _on_tab_selected(index: int) -> void:
	activity_panel.visible = (index == 0)
	graph_panel.visible = (index == 1)

func _on_day_selected(iso: String) -> void:
	_day = iso
	view.render_day(iso)

func _on_activity_changed() -> void:
	calendar.refresh()
	if _day != "":
		view.render_day(_day)
	_refresh_summary()

func _select_day(iso: String) -> void:
	_day = iso
	calendar.set_selected(iso)
	view.render_day(iso)

func _refresh_summary() -> void:
	var today := DateUtil.today_iso()
	today_count_value.text = TranslationServer.translate("RECORD_TODAY_COUNT_VALUE").format({"n": Save.activity_entries_for(today).size()})
	today_time_value.text = DateUtil.format_hm(Save.activity_log.play_days.get(today, 0.0))
	total_focus_value.text = DateUtil.format_hm(Save.voyage.total_focus_seconds)
