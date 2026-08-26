class_name NoteStreamRow
extends PanelContainer

signal selected(event_id: int, meta: String, title: String)

@onready var meta_label: Label = $VBox/MetaLabel
@onready var note_label: Label = $VBox/NoteLabel

var _id: int = 0
var _meta: String = ""
var _title: String = ""

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func setup(d: Dictionary) -> void:
	_id = int(d["id"])
	_meta = str(d["meta"])
	_title = str(d["title"])
	meta_label.text = "%s · %s" % [_meta, _title]
	note_label.text = str(d["note"])
	var base := get_theme_stylebox("panel")
	var sb: StyleBoxFlat = base.duplicate() if base is StyleBoxFlat else StyleBoxFlat.new()
	sb.border_color = d["accent"]            # 씬 리소스를 복제해 색만 덮음(공유 리소스 오염 방지)
	add_theme_stylebox_override("panel", sb)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(_id, _meta, _title)
		accept_event()
