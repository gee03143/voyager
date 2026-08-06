extends HBoxContainer

const TODO_SCENE := preload("res://scenes/todo/TodoListView.tscn")
const HABIT_SCENE := preload("res://scenes/habittracker/HabitTrackerView.tscn")

@onready var nav_list: VBoxContainer = $Sidebar/Margin/VBox/NavList
@onready var content_area: PanelContainer = $MainColumn/BodyRow/ContentArea

const CONTENT_SCENES := {
	1: TODO_SCENE,
	2: HABIT_SCENE,
}

var _nav := ButtonGroupNav.new()
var _content: Node = null

func _ready() -> void:
	_nav.setup_from(nav_list, false)
	_nav.selected.connect(_on_nav_selected)
	_nav.select(0)

func _on_nav_selected(index: int) -> void:
	if _content != null:
		if _content.has_method("on_hidden"):
			_content.on_hidden()
		_content.visible = false
		_content.reparent(PanelPool)
		_content = null
	if CONTENT_SCENES.has(index):
		_content = PanelPool.get_instance(CONTENT_SCENES[index], null)
		_content.reparent(content_area)
		_content.visible = true
		if _content.has_method("on_shown"):
			_content.on_shown()
