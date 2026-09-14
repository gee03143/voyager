class_name GratitudeHistoryRow
extends PanelContainer

signal delete_requested(id: int)

@onready var click_area: HBoxContainer = $Margin/VBox/Head/ClickArea
@onready var chevron: Label = $Margin/VBox/Head/ClickArea/Chevron
@onready var date_label: Label = $Margin/VBox/Head/ClickArea/DateLabel
@onready var summary_label: Label = $Margin/VBox/Head/ClickArea/SummaryLabel
@onready var count_label: Label = $Margin/VBox/Head/ClickArea/CountLabel
@onready var delete_button: HoldButton = $Margin/VBox/Head/DeleteButton
@onready var expand_box: VBoxContainer = $Margin/VBox/ExpandBox

var _id: int = 0
var _items: Array = []
var _expanded: bool = false
var _entry: Dictionary = {}    # _ready 전에 들어온 값. 노드를 만지는 건 _ready 뒤로 미룬다

func _ready() -> void:
	summary_label.clip_text = true
	summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	delete_button.held.connect(func(): delete_requested.emit(_id))
	click_area.gui_input.connect(_on_click_area_input)
	HoverReveal.setup(self, [delete_button])
	if not _entry.is_empty():
		_apply()

func _on_click_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_expanded = not _expanded
		_apply_expanded()

func _apply_expanded() -> void:
	chevron.text = "▾" if _expanded else "▸"
	summary_label.visible = not _expanded
	expand_box.visible = _expanded
	if _expanded:
		_rebuild_expand()

func _rebuild_expand() -> void:
	for c in expand_box.get_children():
		expand_box.remove_child(c)   # queue_free만 하면 같은 프레임의 다음 갱신까지 자식으로 남는다
		c.queue_free()
	for it in _items:
		var t := str(it).strip_edges()
		if t == "":
			continue
		var lbl := Label.new()
		lbl.text = "· %s" % t
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		expand_box.add_child(lbl)

func setup(entry: Dictionary) -> void:
	_entry = entry
	_id = int(entry.get("id", 0))
	_items = entry.get("items", [])
	if is_node_ready():
		_apply()

func _apply() -> void:
	date_label.text = DateUtil.format_day(str(_entry.get("date_iso", "")))
	var parts := []
	for it in _items:
		var t := str(it).strip_edges()
		if t != "":
			parts.append(t)
	summary_label.text = " · ".join(parts) if not parts.is_empty() else TranslationServer.translate("GRATITUDE_EMPTY_ENTRY")
	count_label.text = TranslationServer.translate("GRATITUDE_ITEM_COUNT").format({"n": parts.size()})
	_expanded = false
	_apply_expanded()
