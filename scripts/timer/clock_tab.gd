extends HBoxContainer

@export var nav_slot: TabNavSlot
@export var tab_labels: Array[String] = []
@export var tab_pages: Array[Control] = []

func _ready() -> void:
	if nav_slot == null:
		nav_slot = TabNavSlot.new()
		add_child(nav_slot)
		move_child(nav_slot, 0)
		attach_nav()

func attach_nav() -> void:
	nav_slot.tab_selected.connect(_on_tab_selected)
	nav_slot.set_tabs(tab_labels)

func _on_tab_selected(index: int) -> void:
	for i in tab_pages.size():
		tab_pages[i].visible = (i == index)
