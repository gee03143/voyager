extends Control
class_name PopupFrame

@onready var nav_slot: TabNavSlot = $NavSlot
@onready var content_box: Control = $ContentBox

var _content: Node = null

func show_scene(scene: PackedScene) -> void:
	close()
	_content = scene.instantiate()
	_content.set("nav_slot", nav_slot)
	content_box.add_child(_content)
	visible = true

func close() -> void:
	nav_slot.clear()
	if _content != null:
		_content.queue_free()
		_content = null
	visible = false
