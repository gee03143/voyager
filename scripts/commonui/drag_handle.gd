class_name DragHandle
extends Label

# 재사용 드래그 핸들(⋮⋮). 행 좌측에 둔다.
# _get_drag_data 가 이 노드에만 있어 "핸들에서만 드래그 시작"이 보장된다.
# enabled=false 면 드래그 비활성 + 숨김(수동 정렬이 아닐 때).

@export var token: StringName = &""
var row: Control = null
var enabled: bool = true:
	set(v):
		enabled = v
		visible = v

func _ready() -> void:
	text = "⋮⋮"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	
func _get_drag_data(_pos: Vector2) -> Variant:
	if not enabled or row == null:
		return null
	set_drag_preview(_make_preview(_pos))
	return {"token": token, "row": row}

func _make_preview(at_pos: Vector2) -> Control:
	var ghost: Control
	if row.has_method("make_drag_preview"):
		ghost = row.make_drag_preview()           # 행이 자기 프리뷰 제공
	else:
		ghost = row.duplicate() as Control         # 폴백(그룹 행 등)
		ghost.set_script(null)
	ghost.modulate.a = 0.6
	var wrap := Control.new()
	var grab := (global_position - row.global_position) + at_pos   # 잡은 점을 행 기준으로
	ghost.position = -grab                                          # 그 점이 커서 밑에 오도록
	wrap.add_child(ghost)
	return wrap
