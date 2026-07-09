extends VBoxContainer

@export var nav_slot: TabNavSlot
@export var tab_labels: Array[String] = []
@export var tab_pages: Array[Control] = []
@onready var calendar = $ActivityTab/Calendar
@onready var view = $ActivityTab/RecordView

var _day: String = ""

func _ready() -> void:
	if nav_slot == null:
		nav_slot = TabNavSlot.new()
		add_child(nav_slot)
		move_child(nav_slot, 0)
		attach_nav()
		on_shown()
	calendar.day_selected.connect(_on_day_selected)
	Save.activity_log.changed.connect(_on_changed)
	
func attach_nav() -> void:
	nav_slot.tab_selected.connect(_on_tab_selected)
	nav_slot.set_tabs(tab_labels)

func on_shown() -> void:
	_select_day(DateUtil.today_iso())

func _on_tab_selected(index: int) -> void:
	for i in tab_pages.size():
		tab_pages[i].visible = (i == index)

func _on_day_selected(iso: String) -> void:
	_day = iso
	view.render_day(iso)

func _on_changed() -> void:
	calendar.refresh()
	if _day != "":
		view.render_day(_day)

func _select_day(iso: String) -> void:
	_day = iso
	calendar.set_selected(iso)
	view.render_day(iso)
