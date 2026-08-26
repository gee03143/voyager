class_name NoteStream
extends VBoxContainer

signal entry_selected(event_id: int, meta: String, title: String)

const ROW_SCENE := preload("res://scenes/record/Timeline/NoteStreamRow.tscn")

@onready var title_label: Label = $TitleLabel
@onready var empty_label: Label = $EmptyLabel
@onready var list: VBoxContainer = $Scroll/List

func render(entries: Array) -> void:
	for c in list.get_children():
		c.queue_free()
	title_label.text = TranslationServer.translate("RECORD_NOTE_STREAM_TITLE").format({"n": entries.size()})
	empty_label.visible = entries.is_empty()
	for d in entries:
		var row := ROW_SCENE.instantiate() as NoteStreamRow
		list.add_child(row)                  # setup 전에 트리에 넣어야 @onready가 채워짐
		row.setup(d)
		row.selected.connect(_on_row_selected)

func _on_row_selected(event_id: int, meta: String, title: String) -> void:
	entry_selected.emit(event_id, meta, title)
