extends VBoxContainer

@export var nav_slot: TabNavSlot
@export var tab_labels: Array[String] = []
@export var tab_pages: Array[Control] = []
@onready var quit_button: Button = $EtcTab/QuitButton

func _ready() -> void:
	if nav_slot == null:
		nav_slot = TabNavSlot.new()
		add_child(nav_slot)
		move_child(nav_slot, 0)
	nav_slot.tab_selected.connect(_on_tab_selected)
	nav_slot.set_tabs(tab_labels)
	quit_button.pressed.connect(Save.quit_game)

func _on_tab_selected(index: int) -> void:
	for i in tab_pages.size():
		tab_pages[i].visible = (i == index)
