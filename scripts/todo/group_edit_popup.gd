class_name GroupEditPopup
extends PopupPanel

signal groups_changed                       # 추가/이름변경/삭제 → 뷰가 동기화·저장

@onready var add_group_button: Button = $VBox/AddGroupButton
@onready var close_button: Button = $VBox/CloseButton
@onready var group_list: ReorderList = $VBox/GroupList

func _ready() -> void:
	add_group_button.pressed.connect(_on_add_group)
	close_button.pressed.connect(hide)
	
	group_list.token = &"group"
	group_list.reordered.connect(_on_reordered)

func open() -> void:
	_rebuild()
	popup_centered()

func _rebuild() -> void:
	group_list.clear_items()
	for i in Save.todo_groups.size():
		_add_group_row(i)

func _add_group_row(index: int) -> void:
	var g := Save.todo_groups[index]
	var row := HBoxContainer.new()

	var handle := DragHandle.new()
	handle.token = &"group"
	handle.row = row
	row.add_child(handle)

	var name_edit := LineEdit.new()
	name_edit.text = g.name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t): _on_rename(index, t))
	row.add_child(name_edit)

	var del := Button.new()
	del.text = "✕"
	del.disabled = Save.todo_groups.size() <= 1      # 마지막 그룹은 삭제 불가
	del.pressed.connect(func(): _on_delete(index))
	row.add_child(del)

	group_list.add_child(row)

func _on_add_group() -> void:
	var g := TodoGroup.new()
	g.name = "새 목록"
	Save.todo_groups.append(g)
	_rebuild()                                # 구조 변경 → 팝업 목록 다시 그림
	groups_changed.emit()

func _on_rename(index: int, new_name: String) -> void:
	if index < Save.todo_groups.size():
		Save.todo_groups[index].name = new_name
		groups_changed.emit()                 # _rebuild 안 함(입력 중 포커스 유지)

func _on_delete(index: int) -> void:
	if Save.todo_groups.size() <= 1:
		return
	Save.todo_groups.remove_at(index)
	_rebuild()
	groups_changed.emit()

func _on_reordered(from: int, to: int) -> void:
	var g: TodoGroup = Save.todo_groups[from]
	Save.todo_groups.remove_at(from)
	Save.todo_groups.insert(to, g)
	_rebuild()
	groups_changed.emit()            # TodoView가 활성 인덱스 재계산 + 드롭다운 갱신 + 저장
