class_name LineEditAutoBlur
extends Node

@export var target: Control

func _ready() -> void:
	set_process_input(false)
	if target:
		target.focus_entered.connect(func(): set_process_input(true))
		target.focus_exited.connect(func(): set_process_input(false))

func _input(event: InputEvent) -> void:
	if target and event is InputEventMouseButton and event.pressed \
			and not target.get_global_rect().has_point(event.position):
		# autoload의 _input은 씬 노드보다 늦게 불린다. 포커스를 풀기 전에
		# 확정 대기 중인 조합 문자를 직접 되메워야 한다.
		ImeCommitGuard.flush()
		target.release_focus()
