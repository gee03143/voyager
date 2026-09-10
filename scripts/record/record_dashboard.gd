extends PanelContainer

@onready var tab_row: TabNavSlot = $Margin/Body/Main/TabRow
@onready var activity_panel: HBoxContainer = $Margin/Body/Main/ActivityPanel
@onready var graph_panel: Control = $Margin/Body/Main/GraphPanel
@onready var calendar = $Margin/Body/Main/ActivityPanel/Calendar
@onready var view = $Margin/Body/Main/ActivityPanel/Timeline
@onready var note_editor: NoteEditor = $Margin/Body/Summary/SummaryMargin/SummaryVBox/NoteEditor
@onready var note_stream: NoteStream = $Margin/Body/Summary/SummaryMargin/SummaryVBox/NoteStream

# 바뀌는 영역이 화면 전체보다 작으므로 콘텐츠 스왑(0.35)보다 짧다. F6에서 눈으로 조정할 값.
const TAB_ENTER_SEC := 0.22

var _day: String = ""
var _wrap: Control
var _tween: Tween

func _ready() -> void:
	_init_wrap()
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

# 탭 패널은 한 번에 하나만 보이므로 세로로 쌓아둘 이유가 없다.
# 래퍼 하나에 겹쳐 넣으면 컨테이너가 위치를 되돌리지 않아 연출을 걸 수 있다.
func _init_wrap() -> void:
	_wrap = PanelEnter.make_wrap()
	_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	$Margin/Body/Main.add_child(_wrap)              # TabRow 다음 자리
	PanelEnter.adopt(_wrap, activity_panel)
	PanelEnter.adopt(_wrap, graph_panel)

func _on_tab_selected(index: int) -> void:
	PanelEnter.kill(_tween)
	activity_panel.visible = (index == 0)
	graph_panel.visible = (index == 1)
	var shown: Control = activity_panel if index == 0 else (graph_panel if index == 1 else null)
	if shown == null:
		return
	# 첫 생성은 풀 안에서 일어나 아직 화면에 없다. 그때 연출하면 셸의 진입 연출과 겹쳐 보인다.
	if not is_visible_in_tree():
		PanelEnter.settle(shown)
		return
	_tween = PanelEnter.play(self, shown, TAB_ENTER_SEC)

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
