class_name JournalDocRow
extends PanelContainer

signal selected(id: int)
signal delete_requested(id: int)

@onready var body: VBoxContainer = $HBox/Body
@onready var title_label: Label = $HBox/Body/TitleLabel
@onready var date_label: Label = $HBox/Body/DateLabel
@onready var delete_button: HoldButton = $HBox/DeleteButton

var _id: int = 0

func _ready() -> void:
	body.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(_id))
	delete_button.held.connect(func(): delete_requested.emit(_id))
	HoverReveal.setup(self, [delete_button])

func setup(doc: Dictionary, is_selected: bool) -> void:
	_id = int(doc.get("id", 0))
	var t := str(doc.get("title", "")).strip_edges()
	title_label.text = t if t != "" else "(제목 없음)"
	date_label.text = "생성됨 %s" % DateUtil.format_created(int(doc.get("ts", 0)))
	date_label.modulate.a = 0.6
	if is_selected:
		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(1, 1, 1, 0.10)
		add_theme_stylebox_override("panel", sel)
