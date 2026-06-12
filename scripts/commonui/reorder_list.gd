class_name ReorderList
extends VBoxContainer

# 재사용 드롭 컨테이너. 커서 y로 "어느 행의 위/아래 절반"인지 판정해
# 삽입 인덱스를 계산하고, 드롭 위치 선(인디케이터)을 그린다. Save 는 모름.
signal reordered(from_index: int, to_index: int)

@export var token: StringName = &""

var _indicator: ColorRect
var _overlay: Control

func _ready() -> void:
	_overlay = Control.new()
	_overlay.top_level = true                       # 컨테이너 레이아웃에서 제외
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_drag_forwarding(Callable(), _can_drop_data, _drop_data)
	
	_indicator = ColorRect.new()
	_indicator.color = Color(0.4, 0.7, 1.0)
	_indicator.custom_minimum_size = Vector2(0, 2)
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator.top_level = true                # 컨테이너 레이아웃에서 제외
	_indicator.visible = false
	add_child(_indicator)

func _can_drop_data(pos: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("token", &"") != token:
		_indicator.visible = false
		return false
	_show_indicator(_index_at(pos))
	return true

func _drop_data(pos: Vector2, data: Variant) -> void:
	_indicator.visible = false
	var rows := _rows()
	var from_index: int = rows.find(data.get("row"))
	if from_index == -1:
		return
	var to_index := _index_at(pos)
	if from_index < to_index:
		to_index -= 1                          # 자기 자신을 뺀 뒤 인덱스 보정
	if from_index == to_index:
		return
	reordered.emit(from_index, to_index)
	
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_overlay.global_position = global_position
			_overlay.size = size
			_overlay.mouse_filter = Control.MOUSE_FILTER_STOP   # 리스트 전체가 드롭존
		NOTIFICATION_DRAG_END:
			_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if _indicator:
				_indicator.visible = false

func _rows() -> Array:                         # 드래그 대상 행(인디케이터 제외)
	var out: Array = []
	for c in get_children():
		if c == _indicator or c == _overlay:
			continue
		if c is Control and c.visible:
			out.append(c)
	return out
	
func _index_at(pos: Vector2) -> int:           # 커서 y → 삽입 인덱스(0..n)
	var rows := _rows()
	for i in rows.size():
		var r: Control = rows[i]
		if pos.y < r.position.y + r.size.y * 0.5:
			return i
	return rows.size()

func _show_indicator(index: int) -> void:
	var rows := _rows()
	var y: float = 0.0
	if not rows.is_empty():
		if index >= rows.size():
			var last: Control = rows[-1]
			y = last.position.y + last.size.y
		else:
			y = rows[index].position.y
	_indicator.global_position = global_position + Vector2(0, y)
	_indicator.size.x = size.x
	_indicator.visible = true
