extends HBoxContainer

@onready var nav: VBoxContainer = $NavBar
@onready var pages: TabContainer = $Pages

func _ready() -> void:
	var group := ButtonGroup.new()
	var buttons := nav.get_children()
	for i in buttons.size():
		var b := buttons[i] as Button
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_on_nav_pressed.bind(i))

	if buttons.size() > 0:
		(buttons[0] as Button).button_pressed = true
	pages.current_tab = 0

func _on_nav_pressed(index: int) -> void:
	pages.current_tab = index
