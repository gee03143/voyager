class_name TimelineHabitChip
extends PanelContainer

@onready var label: Label = $Label

func setup(title: String) -> void:
	label.text = title
