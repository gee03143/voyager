extends HBoxContainer

@onready var nav: VBoxContainer = $NavBar
@onready var pages: TabContainer = $Pages

var _nav := ButtonGroupNav.new()

func _ready() -> void:
	_nav.setup_from(nav)
	_nav.selected.connect(_on_nav_selected)
	_nav.select(0)

func _on_nav_selected(index: int) -> void:
	if index >= 0 and index < pages.get_tab_count():
		pages.current_tab = index
