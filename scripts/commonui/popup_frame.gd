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
	_content.reparent(content_box)
	_content.visible = true
	if _content.has_method("on_shown"):
		_content.on_shown()
	visible = true

func close() -> void:
	nav_slot.clear()
	if _content != null:
		if _content.has_method("on_hidden"):
			_content.on_hidden()
		_content.visible = false
		_content.reparent(PanelPool)
		_content = null
	visible = false
