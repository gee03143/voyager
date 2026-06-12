class_name LineEditAutoBlur
extends Node

@export var target: LineEdit

func _ready() -> void:
	set_process_input(false)
	if target:
		target.focus_entered.connect(func(): set_process_input(true))
		target.focus_exited.connect(func(): set_process_input(false))

func _input(event: InputEvent) -> void:
	if target and event is InputEventMouseButton and event.pressed \
			and not target.get_global_rect().has_point(event.position):
		target.release_focus()
