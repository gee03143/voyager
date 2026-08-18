extends PanelContainer

@onready var tab_row: TabNavSlot = $Margin/Main/TabRow
@onready var freeform_tab: Control = $Margin/Main/FreeformTab
@onready var gratitude_tab: Control = $Margin/Main/GratitudeTab
@onready var mood_tab: Control = $Margin/Main/MoodTab

func _ready() -> void:
	tab_row.tab_selected.connect(_on_tab_selected)
	tab_row.set_tabs(["JOURNAL_TAB_FREEFORM", "JOURNAL_TAB_GRATITUDE", "JOURNAL_TAB_MOOD"])

func _on_tab_selected(index: int) -> void:
	freeform_tab.visible = (index == 0)
	gratitude_tab.visible = (index == 1)
	mood_tab.visible = (index == 2)
