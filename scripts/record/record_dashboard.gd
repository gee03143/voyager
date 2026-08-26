extends PanelContainer

@onready var tab_row: TabNavSlot = $Margin/Body/Main/TabRow
@onready var activity_panel: HBoxContainer = $Margin/Body/Main/ActivityPanel
@onready var graph_panel: Control = $Margin/Body/Main/GraphPanel
@onready var calendar = $Margin/Body/Main/ActivityPanel/Calendar
@onready var view = $Margin/Body/Main/ActivityPanel/Timeline
@onready var note_editor: NoteEditor = $Margin/Body/Summary/SummaryMargin/SummaryVBox/NoteEditor
@onready var note_stream: NoteStream = $Margin/Body/Summary/SummaryMargin/SummaryVBox/NoteStream

var _day: String = ""

func _ready() -> void:
	tab_row.tab_selected.connect(_on_tab_selected)
	tab_row.set_tabs(["RECORD_TAB_ACTIVITY", "RECORD_TAB_GRAPH"])
	calendar.day_selected.connect(_on_day_selected)
	view.entry_selected.connect(_on_entry_selected)
	note_editor.back_requested.connect(_on_note_back)
	note_stream.entry_selected.connect(_on_stream_selected)
	view.rendered.connect(_refresh_stream)
	_show_editor(false)
	Save.activity_log.changed.connect(_on_activity_changed)
	if not has_meta("pooled"):
		on_shown()

func on_shown() -> void:
	_select_day(DateUtil.today_iso())

func _on_activity_changed() -> void:
	calendar.refresh()
	if _day != "":
		view.render_day(_day)

func _on_tab_selected(index: int) -> void:
	activity_panel.visible = (index == 0)
	graph_panel.visible = (index == 1)

func _on_day_selected(iso: String) -> void:
	_day = iso
	_on_note_back()
	view.render_day(iso)

func _select_day(iso: String) -> void:
	_day = iso
	calendar.set_selected(iso)
	view.render_day(iso)
	
func _on_entry_selected(event_id: int, meta: String, title: String) -> void:
	note_editor.open_for(event_id, meta, title)
	_show_editor(true)

func _on_note_back() -> void:
	view.clear_selection()
	_show_editor(false)
	
func _on_stream_selected(event_id: int, meta: String, title: String) -> void:
	view.select_entry(event_id)              # 타임라인 하이라이트 동기화
	_on_entry_selected(event_id, meta, title)

func _refresh_stream() -> void:
	note_stream.render(view.entries_with_notes())

func _show_editor(on: bool) -> void:
	note_editor.visible = on
	note_stream.visible = not on
