extends VBoxContainer

@onready var header: Label = $Header
@onready var grid: GridContainer = $Grid

func _ready() -> void:
	grid.columns = 3
	Save.lexicon.changed.connect(_rebuild)
	visibility_changed.connect(func(): if visible: _rebuild())
	_rebuild()


func _rebuild() -> void:
	for c in grid.get_children():
		c.queue_free()
	var unlocked := 0
	for s in ActivityVocab.SUBJECTS:
		var key := str(s["key"])
		var has := Save.lexicon.has_subject(key)
		if has:
			unlocked += 1
		var cell := Label.new()
		cell.text = str(s["ko"]) if has else "???"
		cell.modulate.a = 1.0 if has else 0.4
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.custom_minimum_size = Vector2(84, 34)
		grid.add_child(cell)
	header.text = "활동 어휘  %d / %d" % [unlocked, ActivityVocab.SUBJECTS.size()]
