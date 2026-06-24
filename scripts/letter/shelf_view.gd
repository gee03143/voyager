extends PanelContainer

@onready var _list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var _close: Button = $Margin/VBox/Header/Close

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	_close.pressed.connect(_on_close_pressed)

func _on_visibility_changed() -> void:
	if visible:                       # 열 때마다 최신 컬렉션으로 재구성
		_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var recv := Save.letters.received()
	if recv.is_empty():
		var empty := Label.new()
		empty.text = "아직 보관한 편지가 없어요"
		_list.add_child(empty)
		return
	for L in recv:
		var lbl := Label.new()
		lbl.text = TelegraphContent.render(int(L["template_idx"]), str(L["subject"]), str(L["fact"]), str(L["state"]))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_list.add_child(lbl)

func _on_close_pressed() -> void:
	visible = false
