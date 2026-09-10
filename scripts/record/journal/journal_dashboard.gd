extends PanelContainer

@onready var tab_row: TabNavSlot = $Margin/Main/TabRow
@onready var freeform_tab: Control = $Margin/Main/FreeformTab
@onready var gratitude_tab: Control = $Margin/Main/GratitudeTab
@onready var mood_tab: Control = $Margin/Main/MoodTab
@onready var main_vbox: VBoxContainer = $Margin/Main

# 바뀌는 영역이 화면 전체보다 작으므로 콘텐츠 스왑(0.35)보다 짧다. F6에서 눈으로 조정할 값.
const TAB_ENTER_SEC := 0.22

var _wrap: Control
var _tween: Tween

func _ready() -> void:
	_init_wrap()
	tab_row.tab_selected.connect(_on_tab_selected)
	tab_row.set_tabs(["JOURNAL_TAB_FREEFORM", "JOURNAL_TAB_GRATITUDE", "JOURNAL_TAB_MOOD"])

# 탭 패널은 한 번에 하나만 보이므로 세로로 쌓아둘 이유가 없다.
# 래퍼 하나에 겹쳐 넣으면 컨테이너가 위치를 되돌리지 않아 연출을 걸 수 있다.
func _init_wrap() -> void:
	_wrap = PanelEnter.make_wrap()
	_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_wrap)                     # TabRow 다음 자리
	for tab in [freeform_tab, gratitude_tab, mood_tab]:
		PanelEnter.adopt(_wrap, tab)

func _on_tab_selected(index: int) -> void:
	PanelEnter.kill(_tween)
	freeform_tab.visible = (index == 0)
	gratitude_tab.visible = (index == 1)
	mood_tab.visible = (index == 2)
	var shown: Control = [freeform_tab, gratitude_tab, mood_tab][index] if index >= 0 and index < 3 else null
	if shown == null:
		return
	# 첫 생성은 풀 안에서 일어나 아직 화면에 없다. 그때 연출하면 셸의 진입 연출과 겹쳐 보인다.
	if not is_visible_in_tree():
		PanelEnter.settle(shown)
		return
	_tween = PanelEnter.play(self, shown, TAB_ENTER_SEC)
