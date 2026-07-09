extends Control
class_name PopupFrame

@onready var nav_slot: TabNavSlot = $NavSlot
@onready var content_box: Control = $ContentBox

var _content: Node = null

func show_scene(scene: PackedScene) -> void:
	close()
	_content = PanelPool.get_instance(scene, nav_slot)
	_content.set("nav_slot", nav_slot)
	if _content.has_method("attach_nav"):
		_content.attach_nav()
	content_box.add_child(_content)
	if _content.has_method("on_shown"):
		_content.on_shown()
	visible = true

func close() -> void:
	nav_slot.clear()
	if _content != null:
		if _content.has_method("on_hidden"):
			_content.on_hidden()
		content_box.remove_child(_content)
		_content = null
	visible = false
