extends Node

var _pool: Dictionary = {}

func get_instance(scene: PackedScene, nav_slot: TabNavSlot) -> Node:
	if not _pool.has(scene):
		var node := scene.instantiate()
		node.set("nav_slot", nav_slot)
		node.set_meta("pooled", true)
		add_child(node)
		remove_child(node)
		_pool[scene] = node
	return _pool[scene]
