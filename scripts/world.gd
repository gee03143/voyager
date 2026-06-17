extends Node2D

@export var dock: Container          # 토글 버튼들의 부모
@export var panels: Array[Control]   # 도크 버튼 순서대로의 패널 (항해처럼 없으면 비워둠)

var _nav := ButtonGroupNav.new()

func _ready() -> void:
	_nav.setup_from(dock)
	_nav.selected.connect(_on_nav_selected)
	_nav.select(dock.get_child_count() - 1)   # 시작 = 마지막 버튼(항해) = 월드만

func _on_nav_selected(index: int) -> void:
	for p in panels:
		if p != null:
			p.visible = false
	if index >= 0 and index < panels.size() and panels[index] != null:
		panels[index].visible = true
