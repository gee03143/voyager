class_name Notice
extends PanelContainer

@onready var _label: Label = $Margin/Label

var _left := 0.0

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			visible = false

func show_notice(text: String, duration := 3.5) -> void:
	_label.text = text
	visible = true
	_left = duration
