extends HBoxContainer

@onready var nav: VBoxContainer = $NavBar
@onready var pages: TabContainer = $Pages

func _ready() -> void:
	var group := ButtonGroup.new()
	var idx := 0
	for child in nav.get_children():
		if child is Button:
			child.toggle_mode = true
			child.button_group = group
			child.pressed.connect(_on_nav_pressed.bind(idx))
			if idx == 0:
				child.button_pressed = true
			idx += 1
	pages.current_tab = 0

func _on_nav_pressed(index: int) -> void:
	if index < pages.get_tab_count():
		pages.current_tab = index
