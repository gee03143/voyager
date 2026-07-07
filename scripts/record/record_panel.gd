extends VBoxContainer

@onready var tab_nav: HBoxContainer = $TabNav
@onready var calendar = $Content/Host/ActivityTab/Calendar
@onready var view = $Content/Host/ActivityTab/RecordView
@onready var _pages: Array = [$Content/Host/ActivityTab, $Content/Host/GraphTab, $Content/Host/JournalTab]

var _nav := ButtonGroupNav.new()
var _day: String = ""

func _ready() -> void:
	_nav.setup_from(tab_nav, false)
	_nav.selected.connect(_on_tab_selected)
	calendar.day_selected.connect(_on_day_selected)
	Save.activity_log.changed.connect(_on_changed)
	visibility_changed.connect(_on_visibility)
	_select_day(DateUtil.today_iso())
	_nav.select(0)

func _on_tab_selected(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = (i == index)

func _on_day_selected(iso: String) -> void:
	_day = iso
	view.render_day(iso)

func _on_changed() -> void:
	calendar.refresh()
	if _day != "":
		view.render_day(_day)

func _on_visibility() -> void:
	if visible:
		calendar.refresh()
		_select_day(DateUtil.today_iso())

func _select_day(iso: String) -> void:
	_day = iso
	calendar.set_selected(iso)
	view.render_day(iso)
